import AppKit
import Foundation
import HeyMacCore
import HeyMacEngine
import Observation
import SwiftUI

/// Orchestrates Face AutoFill for saved credentials into active applications or websites.
@MainActor
final class AutoFillController {
    static let shared = AutoFillController()

    var faceMatcher: () -> FaceMatching? = { nil }
    private(set) var targetApp: NSRunningApplication?
    private var quickPickerWindow: NSWindow?
    private var verificationTask: Task<Void, Never>?
    private let typist = KeystrokeInjector()

    /// Triggers Face AutoFill. If a specific credential is given, fills it immediately.
    /// Otherwise, checks the frontmost app to find matching credentials or opens the Quick Picker.
    func triggerAutoFill(credential: Credential? = nil) {
        // Find frontmost application (excluding Hey Mac itself)
        let front = NSWorkspace.shared.frontmostApplication
        let app = (front?.bundleIdentifier == Bundle.main.bundleIdentifier) ? targetApp : front
        targetApp = app

        guard let vault = AppModel.shared.runtime?.credentialVault else {
            AppModel.shared.openSettings()
            return
        }

        let allCredentials = vault.loadCredentials()
        guard !allCredentials.isEmpty else {
            // No credentials saved yet: direct the user to Settings -> AutoFill
            AppModel.shared.openSettings()
            SettingsSelection.shared.pane = .autoFill
            return
        }

        if let cred = credential {
            fillWithFaceVerification(cred, in: app)
            return
        }

        let appName = app?.localizedName ?? ""
        let matches = vault.findMatches(for: appName)

        if matches.count == 1, let exact = matches.first {
            fillWithFaceVerification(exact, in: app)
        } else {
            showQuickPicker(initialSearch: appName, matches: matches.isEmpty ? allCredentials : matches)
        }
    }

    /// Verifies the user's face using CoreML, then types the credentials into the target app.
    func fillWithFaceVerification(_ credential: Credential, in app: NSRunningApplication?) {
        closeQuickPicker()
        verificationTask?.cancel()

        guard let matcher = faceMatcher() else {
            // Face recognition not ready or paused: open face setup
            AppModel.shared.openSettings()
            SettingsSelection.shared.pane = .face
            return
        }

        NotchOverlayController.shared.beginScanning(onLockScreen: false)

        verificationTask = Task { [weak self] in
            guard let self else { return }

            // Run face verification
            let outcome = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInteractive).async {
                    let result = matcher.run(timeout: 4.0, requiredConsecutive: 2, waitForTurn: 1.0) {
                        !Task.isCancelled
                    }
                    continuation.resume(returning: result)
                }
            }

            guard !Task.isCancelled else {
                NotchOverlayController.shared.cancelScanning()
                return
            }

            if outcome.matched {
                NotchOverlayController.shared.finish(success: true)
                try? await Task.sleep(for: .milliseconds(400))

                // Reactivate target application
                if let app, !app.isTerminated {
                    app.activate()
                    try? await Task.sleep(for: .milliseconds(150))
                }

                // Inject credentials via KeystrokeInjector
                do {
                    try self.typist.typeCredential(username: credential.username, password: credential.password)
                } catch {
                    AppLog.shared.write("AutoFill typing error: \(error)")
                }
            } else {
                NotchOverlayController.shared.finish(success: false)
            }
        }
    }

    // MARK: - Quick Picker Window

    func showQuickPicker(initialSearch: String, matches: [Credential]) {
        closeQuickPicker()

        let pickerState = AutoFillPickerState.shared
        pickerState.search = initialSearch
        pickerState.credentials = matches
        pickerState.onSelect = { [weak self] cred in
            guard let self else { return }
            self.fillWithFaceVerification(cred, in: self.targetApp)
        }
        pickerState.onCancel = { [weak self] in
            self?.closeQuickPicker()
        }

        let view = AutoFillQuickPickerView(state: pickerState)
        let hosting = NSHostingView(rootView: view)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        window.isFloatingPanel = true
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = hosting
        window.center()

        self.quickPickerWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeQuickPicker() {
        quickPickerWindow?.close()
        quickPickerWindow = nil
    }
}
