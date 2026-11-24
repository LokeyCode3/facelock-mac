import Foundation
import HeyMacCore

/// Manages encrypted storage and import of saved credentials for Face AutoFill.
public final class CredentialVault: @unchecked Sendable {
    private let store: SecureStore
    private let lock = NSLock()
    private var cachedCredentials: [Credential]?

    public init(store: SecureStore) {
        self.store = store
    }

    /// Loads all credentials from the encrypted store.
    public func loadCredentials() -> [Credential] {
        lock.withLock {
            if let cached = cachedCredentials {
                return cached
            }
            guard let data = try? store.load(StoredItems.credentialVault),
                  let items = try? JSONDecoder().decode([Credential].self, from: data) else {
                cachedCredentials = []
                return []
            }
            cachedCredentials = items
            return items
        }
    }

    /// Saves all credentials into the encrypted store.
    public func saveCredentials(_ items: [Credential]) throws {
        try lock.withLock {
            let data = try JSONEncoder().encode(items)
            try store.save(data, as: StoredItems.credentialVault)
            cachedCredentials = items
        }
    }

    /// Adds or updates a credential.
    public func upsert(_ credential: Credential) throws {
        var current = loadCredentials()
        if let index = current.firstIndex(where: { $0.id == credential.id }) {
            current[index] = credential
        } else {
            current.append(credential)
        }
        try saveCredentials(current)
    }

    /// Deletes a credential by ID.
    public func delete(id: UUID) throws {
        var current = loadCredentials()
        current.removeAll { $0.id == id }
        try saveCredentials(current)
    }

    /// Finds matching credentials for a query or app title.
    public func findMatches(for target: String) -> [Credential] {
        let items = loadCredentials()
        guard !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return items
        }
        return items.filter { $0.matches(target: target) }
    }

    // MARK: - Apple Passwords CSV Import

    public struct ImportResult: Equatable, Sendable {
        public var importedCount: Int
        public var totalCount: Int
    }

    /// Imports credentials from an Apple Passwords exported CSV string.
    ///
    /// Header row format typically: `Title,URL,Username,Password,Notes,OTPAuth`
    public func importFromApplePasswordsCSV(_ csvContent: String) throws -> ImportResult {
        let rows = CSVParser.parse(csvContent)
        guard let headerRow = rows.first, !headerRow.isEmpty else {
            return ImportResult(importedCount: 0, totalCount: loadCredentials().count)
        }

        // Map column indices
        var titleIdx: Int?
        var urlIdx: Int?
        var usernameIdx: Int?
        var passwordIdx: Int?
        var notesIdx: Int?
        var otpIdx: Int?

        for (i, rawCol) in headerRow.enumerated() {
            let col = rawCol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if col == "title" { titleIdx = i }
            else if col == "url" || col == "uri" || col == "website" { urlIdx = i }
            else if col == "username" || col == "user" || col == "email" { usernameIdx = i }
            else if col == "password" || col == "pass" { passwordIdx = i }
            else if col == "notes" || col == "note" { notesIdx = i }
            else if col == "otpauth" || col == "otp" { otpIdx = i }
        }

        guard let passIdx = passwordIdx else {
            // Cannot import credentials without a password column
            return ImportResult(importedCount: 0, totalCount: loadCredentials().count)
        }

        var newCredentials: [Credential] = []
        for row in rows.dropFirst() {
            guard row.indices.contains(passIdx) else { continue }
            let password = row[passIdx].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !password.isEmpty else { continue }

            let title = (titleIdx != nil && row.indices.contains(titleIdx!)) ? row[titleIdx!].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let url = (urlIdx != nil && row.indices.contains(urlIdx!)) ? row[urlIdx!].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let username = (usernameIdx != nil && row.indices.contains(usernameIdx!)) ? row[usernameIdx!].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let notes = (notesIdx != nil && row.indices.contains(notesIdx!)) ? row[notesIdx!].trimmingCharacters(in: .whitespacesAndNewlines) : nil
            let otp = (otpIdx != nil && row.indices.contains(otpIdx!)) ? row[otpIdx!].trimmingCharacters(in: .whitespacesAndNewlines) : nil

            let effectiveTitle = !title.isEmpty ? title : (!url.isEmpty ? url : "Imported Login")

            newCredentials.append(Credential(
                title: effectiveTitle,
                url: url,
                username: username,
                password: password,
                notes: notes?.isEmpty == true ? nil : notes,
                otpAuth: otp?.isEmpty == true ? nil : otp
            ))
        }

        var existing = loadCredentials()
        // Deduplicate or append: if an item matches (url or title) and username, update password
        var importedCount = 0
        for incoming in newCredentials {
            if let index = existing.firstIndex(where: {
                ($0.url == incoming.url || $0.title == incoming.title) && $0.username == incoming.username
            }) {
                existing[index].password = incoming.password
                existing[index].notes = incoming.notes ?? existing[index].notes
                existing[index].otpAuth = incoming.otpAuth ?? existing[index].otpAuth
                existing[index].updatedAt = Date()
            } else {
                existing.append(incoming)
            }
            importedCount += 1
        }

        try saveCredentials(existing)
        return ImportResult(importedCount: importedCount, totalCount: existing.count)
    }
}

// MARK: - RFC 4180 Compliant CSV Parser

public enum CSVParser {
    public static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        let scalars = Array(text.unicodeScalars)
        var i = 0

        while i < scalars.count {
            let ch = scalars[i]

            if insideQuotes {
                if ch == "\"" {
                    // Check for escaped quote ""
                    if i + 1 < scalars.count && scalars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        // Closing quote
                        insideQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(Character(ch))
                    i += 1
                }
            } else {
                if ch == "\"" {
                    insideQuotes = true
                    i += 1
                } else if ch == "," {
                    currentRow.append(currentField)
                    currentField = ""
                    i += 1
                } else if ch == "\r" {
                    // Check for \r\n
                    if i + 1 < scalars.count && scalars[i + 1] == "\n" {
                        i += 1
                    }
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    i += 1
                } else if ch == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    i += 1
                } else {
                    currentField.append(Character(ch))
                    i += 1
                }
            }
        }

        // Add any remaining field and row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}
