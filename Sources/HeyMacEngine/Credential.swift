import Foundation

/// A single saved login credential (e.g. imported from Apple Passwords or entered by user).
public struct Credential: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var url: String
    public var username: String
    public var password: String
    public var notes: String?
    public var otpAuth: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        url: String = "",
        username: String,
        password: String,
        notes: String? = nil,
        otpAuth: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.username = username
        self.password = password
        self.notes = notes
        self.otpAuth = otpAuth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Cleaned hostname or domain for display and matching.
    public var displayHost: String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return title }
        let fullURLString = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        if let host = URL(string: fullURLString)?.host {
            let lower = host.lowercased()
            return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
        }
        return trimmed
    }

    /// Whether this credential matches a search query or an active application/window context.
    public func matches(target: String) -> Bool {
        let clean = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return false }
        if title.lowercased().contains(clean) || clean.contains(title.lowercased()) {
            return true
        }
        let host = displayHost.lowercased()
        if !host.isEmpty && (host.contains(clean) || clean.contains(host)) {
            return true
        }
        if username.lowercased().contains(clean) {
            return true
        }
        return false
    }
}
