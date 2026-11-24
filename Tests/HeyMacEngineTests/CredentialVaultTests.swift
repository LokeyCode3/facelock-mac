import Testing
import Foundation
import CryptoKit
import HeyMacCore
@testable import HeyMacEngine

private struct EphemeralKeyProvider: SymmetricKeyProviding {
    let key = CryptoKit.SymmetricKey(size: .bits256)
    func fetchOrCreateKey() throws -> CryptoKit.SymmetricKey { key }
}

private func makeTempDir() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func csvParserParsesStandardAndQuotedFields() {
    let line1 = "Title,URL,Username,Password,Notes,OTPAuth\n"
    let line2 = "\"Amazon\",\"https://www.amazon.com/\",\"user@example.com\",\"secret123\",\"\",\"\"\n"
    let line3 = "\"Google\",\"accounts.google.com\",\"test@gmail.com\",\"p@ss,with,comma\",\"Note with \"\"quotes\"\"\",\"otpauth://totp/...\"\n"
    let csv = line1 + line2 + line3

    let rows = CSVParser.parse(csv)
    #expect(rows.count == 3)
    #expect(rows[0] == ["Title", "URL", "Username", "Password", "Notes", "OTPAuth"])
    #expect(rows[1] == ["Amazon", "https://www.amazon.com/", "user@example.com", "secret123", "", ""])
    #expect(rows[2] == ["Google", "accounts.google.com", "test@gmail.com", "p@ss,with,comma", "Note with \"quotes\"", "otpauth://totp/..."])
}

@Test func credentialDisplayHostAndMatching() {
    let cred = Credential(title: "Amazon Shopping", url: "https://www.amazon.com/ap/signin", username: "shopper@amazon.com", password: "pwd")
    #expect(cred.displayHost == "amazon.com")
    #expect(cred.matches(target: "Amazon"))
    #expect(cred.matches(target: "amazon.com"))
    #expect(cred.matches(target: "shopper"))
    #expect(!cred.matches(target: "netflix"))
}

@Test func credentialVaultSaveLoadAndAppleCSVImport() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = SecureStore(keyProvider: EphemeralKeyProvider(), directory: dir)
    let vault = CredentialVault(store: store)

    #expect(vault.loadCredentials().isEmpty)

    let line1 = "Title,URL,Username,Password,Notes,OTPAuth\n"
    let line2 = "\"Amazon\",\"https://www.amazon.com/\",\"buyer@amazon.com\",\"pass1\",\"note\",\"\"\n"
    let line3 = "\"Netflix\",\"https://netflix.com\",\"watcher@netflix.com\",\"pass2\",\"\",\"\"\n"
    let appleCSV = line1 + line2 + line3

    let result = try vault.importFromApplePasswordsCSV(appleCSV)
    #expect(result.importedCount == 2)
    #expect(result.totalCount == 2)

    let loaded = vault.loadCredentials()
    #expect(loaded.count == 2)
    #expect(loaded.first { $0.title == "Amazon" }?.password == "pass1")
    #expect(loaded.first { $0.title == "Netflix" }?.password == "pass2")

    // Test upserting
    var amazon = loaded.first { $0.title == "Amazon" }!
    amazon.password = "newPass123"
    try vault.upsert(amazon)

    let reloaded = vault.loadCredentials()
    #expect(reloaded.first { $0.title == "Amazon" }?.password == "newPass123")

    // Test delete
    try vault.delete(id: amazon.id)
    #expect(vault.loadCredentials().count == 1)
}
