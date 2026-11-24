import AppKit
import Foundation
import HeyMacEngine
import Observation
import SwiftUI

@MainActor @Observable
final class AutoFillPaneState {
    static let shared = AutoFillPaneState()

    var credentials: [Credential] = []
    var searchQuery = ""
    var isAddingNew = false
    var revealedPasswordIDs: Set<UUID> = []

    var newTitle = ""
    var newURL = ""
    var newUsername = ""
    var newPassword = ""

    var statusMessage: String?
    var statusTone: Tone = .good

    enum Tone { case good, warn }

    var filteredCredentials: [Credential] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return credentials }
        return credentials.filter { $0.matches(target: q) }
    }

    func refresh(from vault: CredentialVault?) {
        credentials = vault?.loadCredentials() ?? []
    }

    func togglePasswordReveal(for id: UUID) {
        if revealedPasswordIDs.contains(id) {
            revealedPasswordIDs.remove(id)
        } else {
            revealedPasswordIDs.insert(id)
        }
    }

    func copyToClipboard(_ text: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = "Copied \(label) to clipboard"
        statusTone = .good
    }

    func startNew() {
        newTitle = ""
        newURL = ""
        newUsername = ""
        newPassword = ""
        isAddingNew = true
    }

    func saveNew(to vault: CredentialVault?) {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !pass.isEmpty else { return }

        let cred = Credential(
            title: title,
            url: newURL.trimmingCharacters(in: .whitespacesAndNewlines),
            username: newUsername.trimmingCharacters(in: .whitespacesAndNewlines),
            password: pass
        )

        try? vault?.upsert(cred)
        isAddingNew = false
        refresh(from: vault)
        statusMessage = "Added login for \(title)"
        statusTone = .good
    }

    func delete(_ id: UUID, from vault: CredentialVault?) {
        try? vault?.delete(id: id)
        revealedPasswordIDs.remove(id)
        refresh(from: vault)
        statusMessage = "Deleted login"
        statusTone = .good
    }

    func importAppleCSV(into vault: CredentialVault?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.title = "Select Apple Passwords CSV Export"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                if let result = try vault?.importFromApplePasswordsCSV(content) {
                    refresh(from: vault)
                    statusMessage = "Successfully imported \(result.importedCount) logins from Apple Passwords!"
                    statusTone = .good
                }
            } catch {
                statusMessage = "Failed to import CSV: \(error.localizedDescription)"
                statusTone = .warn
            }
        }
    }
}

/// Rich, native macOS settings pane for managing saved credentials and Apple Passwords import.
struct AutoFillPane: View {
    let model: AppModel
    private let state = AutoFillPaneState.shared

    var body: some View {
        PaneTitle("AutoFill & Passwords", subtitle: "Unlock and autofill your web and app logins with a single glance.")

        // Top Status Chips
        HStack(spacing: Spacing.sm) {
            StatusChip(text: "\(state.credentials.count) Saved Logins", tone: state.credentials.isEmpty ? .idle : .good)
            StatusChip(text: "100% On-Device", tone: .good)
            StatusChip(text: "AES-GCM Keychain Encrypted", tone: .idle)
        }
        .padding(.bottom, Spacing.xs)

        // Notification banner if any
        if let msg = state.statusMessage {
            HStack(spacing: Spacing.sm) {
                Image(systemName: state.statusTone == .good ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(state.statusTone == .good ? Theme.goodText : Theme.warnText)
                Text(msg)
                    .font(Typography.caption)
                    .foregroundStyle(state.statusTone == .good ? Theme.goodText : Theme.warnText)
                Spacer()
                Button(action: { state.statusMessage = nil }) {
                    Image(systemName: "xmark").font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.sm)
            .background(state.statusTone == .good ? Theme.good.opacity(0.12) : Theme.warn.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }

        // Apple Passwords Integration Card
        PaneSection(header: "Apple Passwords Integration") {
            SettingsCard {
                HStack(alignment: .top, spacing: Spacing.lg) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(hex: 0x0071E3), Color(hex: 0x5856D6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                        Image(systemName: "key.horizontal.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import from Apple Passwords")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Export your passwords from the macOS Passwords app (File → Export All Passwords…) and select the CSV file here to use Face ID AutoFill.")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: Spacing.md) {
                            Button(action: { state.importAppleCSV(into: model.runtime?.credentialVault) }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Import Passwords.csv…")
                                }
                            }
                            .buttonStyle(PillButtonStyle(kind: .primary))

                            Button(action: { AutoFillController.shared.triggerAutoFill() }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "faceid")
                                    Text("Test AutoFill Now")
                                }
                            }
                            .buttonStyle(PillButtonStyle(kind: .secondary))
                        }
                        .padding(.top, Spacing.xs)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Spacing.md)
            }
        }

        // Saved Logins List
        PaneSection {
            HStack(alignment: .center) {
                SectionHeader("Saved Logins (\(state.filteredCredentials.count))")
                Spacer()

                if !state.credentials.isEmpty {
                    // Search field inside settings
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField("Filter logins…", text: Binding(get: { state.searchQuery }, set: { state.searchQuery = $0 }))
                            .textFieldStyle(.plain)
                            .font(Typography.caption)
                            .frame(width: 140)
                        if !state.searchQuery.isEmpty {
                            Button(action: { state.searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Surface.subtle)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Surface.hairline, lineWidth: 1)
                    )
                }

                Button(action: { state.startNew() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Login")
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            // New Login Card Form
            if state.isAddingNew {
                SettingsCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            Text("Add New Login")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Button("Cancel") { state.isAddingNew = false }
                                .font(Typography.caption)
                                .buttonStyle(.plain)
                        }

                        VStack(spacing: Spacing.sm) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "tag").frame(width: 16).foregroundStyle(.secondary)
                                TextField("Title (e.g. Amazon, Google)", text: Binding(get: { state.newTitle }, set: { state.newTitle = $0 }))
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "globe").frame(width: 16).foregroundStyle(.secondary)
                                TextField("Website URL (e.g. https://amazon.com)", text: Binding(get: { state.newURL }, set: { state.newURL = $0 }))
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "person").frame(width: 16).foregroundStyle(.secondary)
                                TextField("Username or Email", text: Binding(get: { state.newUsername }, set: { state.newUsername = $0 }))
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "lock").frame(width: 16).foregroundStyle(.secondary)
                                SecureField("Password", text: Binding(get: { state.newPassword }, set: { state.newPassword = $0 }))
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        HStack {
                            Spacer()
                            Button("Save Login") { state.saveNew(to: model.runtime?.credentialVault) }
                                .buttonStyle(PillButtonStyle(kind: .primary))
                                .disabled(state.newTitle.isEmpty || state.newPassword.isEmpty)
                        }
                    }
                    .padding(Spacing.md)
                }
            }

            // Empty State
            if state.credentials.isEmpty && !state.isAddingNew {
                SettingsCard {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "key.slash")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                            .padding(.top, Spacing.xs)
                        Text("No saved logins yet")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Import your Apple Passwords or click 'Add Login' to unlock websites with Face ID.")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.xl)
                }
            } else if state.filteredCredentials.isEmpty && !state.credentials.isEmpty {
                SettingsCard {
                    Text("No logins match '\(state.searchQuery)'")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.lg)
                }
            } else {
                SettingsCard {
                    ForEach(state.filteredCredentials) { cred in
                        let isRevealed = state.revealedPasswordIDs.contains(cred.id)
                        HStack(spacing: Spacing.md) {
                            DomainAvatarView(title: cred.title, domain: cred.displayHost, size: 36)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(cred.title)
                                    .font(.system(size: 13.5, weight: .semibold))

                                HStack(spacing: 6) {
                                    if !cred.username.isEmpty {
                                        Text(cred.username)
                                            .font(Typography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !cred.url.isEmpty {
                                        Text("•")
                                            .font(Typography.caption)
                                            .foregroundStyle(.tertiary)
                                        Text(cred.displayHost)
                                            .font(Typography.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                // Password row with reveal & copy
                                HStack(spacing: 8) {
                                    Text(isRevealed ? cred.password : "••••••••••••")
                                        .font(.system(size: 12, weight: .medium, design: isRevealed ? .monospaced : .default))
                                        .foregroundStyle(isRevealed ? Theme.accent : .secondary)

                                    Button(action: { state.togglePasswordReveal(for: cred.id) }) {
                                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help(isRevealed ? "Hide Password" : "Show Password")
                                }
                                .padding(.top, 1)
                            }

                            Spacer(minLength: Spacing.sm)

                            // Quick actions
                            HStack(spacing: Spacing.xs) {
                                if !cred.username.isEmpty {
                                    Button(action: { state.copyToClipboard(cred.username, label: "Username") }) {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy Username")
                                }

                                Button(action: { state.copyToClipboard(cred.password, label: "Password") }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Copy Password")

                                Button(action: {
                                    AutoFillController.shared.fillWithFaceVerification(cred, in: NSWorkspace.shared.frontmostApplication)
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "faceid")
                                        Text("Fill")
                                    }
                                    .font(.system(size: 11.5, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                                .help("AutoFill this login into frontmost window")

                                Button(action: { state.delete(cred.id, from: model.runtime?.credentialVault) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Delete Saved Login")
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)

                        if cred.id != state.filteredCredentials.last?.id {
                            RowDivider(inset: 56)
                        }
                    }
                }
            }
        }
        .onAppear {
            state.refresh(from: model.runtime?.credentialVault)
        }
    }
}
