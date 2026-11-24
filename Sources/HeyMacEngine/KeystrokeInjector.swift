import Foundation
import ApplicationServices
import CoreGraphics
import HeyMacCore

public enum KeystrokeError: Error {
    case accessibilityNotGranted
    case eventCreationFailed
}

/// Types a password into the lock screen by posting synthetic key events at the HID tap
/// (the level that reaches the secure text field), then presses Return.
public final class KeystrokeInjector: PasswordTyping {
    public init() {}

    public static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// One key press: what to send and whether to wait after releasing it.
    private struct Press {
        var virtualKey: CGKeyCode
        /// Set for text: the character is injected as Unicode so keyboard layout doesn't matter.
        var unicode: [UInt16]?
        var waitAfterRelease: Bool
    }

    private static let returnKey: CGKeyCode = 0x24
    private static let tabKey: CGKeyCode = 0x30
    private static let settle: TimeInterval = 0.012

    public func type(_ text: String) throws {
        guard Self.isAccessibilityTrusted() else { throw KeystrokeError.accessibilityNotGranted }
        let source = CGEventSource(stateID: .hidSystemState)
        for press in Self.textPresses(for: text) {
            try Self.send(press, source: source)
        }
    }

    public func typeTab() throws {
        guard Self.isAccessibilityTrusted() else { throw KeystrokeError.accessibilityNotGranted }
        let source = CGEventSource(stateID: .hidSystemState)
        try Self.send(Press(virtualKey: Self.tabKey, unicode: nil, waitAfterRelease: true), source: source)
    }

    public func typeAndReturn(_ text: String) throws {
        guard Self.isAccessibilityTrusted() else { throw KeystrokeError.accessibilityNotGranted }
        let source = CGEventSource(stateID: .hidSystemState)
        for press in Self.presses(for: text) {
            try Self.send(press, source: source)
        }
    }

    /// Injects a username, tabs to the password field, types the password, and optionally submits.
    public func typeCredential(username: String?, password: String, pressReturn: Bool = false) throws {
        if let username, !username.isEmpty {
            try type(username)
            Thread.sleep(forTimeInterval: 0.05)
            try typeTab()
            Thread.sleep(forTimeInterval: 0.05)
        }
        if pressReturn {
            try typeAndReturn(password)
        } else {
            try type(password)
        }
    }

    /// Presses for plain text without trailing Return.
    private static func textPresses(for text: String) -> [Press] {
        text.map { Press(virtualKey: 0, unicode: Array(String($0).utf16), waitAfterRelease: true) }
    }

    /// The whole sequence: every character, then Return (which needs no trailing wait).
    private static func presses(for text: String) -> [Press] {
        textPresses(for: text) + [Press(virtualKey: returnKey, unicode: nil, waitAfterRelease: false)]
    }

    private static func send(_ press: Press, source: CGEventSource?) throws {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: press.virtualKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: press.virtualKey, keyDown: false)
        else { throw KeystrokeError.eventCreationFailed }

        if let unicode = press.unicode {
            unicode.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                for event in [down, up] {
                    event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
                }
            }
        }
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: settle)
        up.post(tap: .cghidEventTap)
        if press.waitAfterRelease { Thread.sleep(forTimeInterval: settle) }
    }
}
