import Foundation
import Security

private struct ProjectSecretsPayload: Codable {
    var version: Int = 1
    var valuesBySecretID: [String: String]
}

private struct LegacySecretEntry: Codable {
    var id: UUID
    var key: String
    var value: String
    var provider: String
    var providerIcon: String
    var secretStorageID: String
    var isPlaceholder: Bool?
}

private struct LegacyProject: Codable {
    var id: UUID
    var name: String
    var secrets: [LegacySecretEntry]
    var lastModified: Date?
}

enum KeychainMigration {
    private static let service = "com.daniel.secretmanager"
    private static let projectAccountPrefix = "project:"
    private static let migrationFlagKey = "didMigrateKeychainToJSON"

    static var didMigrate: Bool {
        UserDefaults.standard.bool(forKey: migrationFlagKey)
    }

    static func markMigrated() {
        UserDefaults.standard.set(true, forKey: migrationFlagKey)
    }

    /// Reads legacy projects.json (with secretStorageID) and hydrates values from Keychain.
    /// Returns true if any values were migrated.
    static func migrateSecrets(into projects: inout [Project], from projectsURL: URL) -> Bool {
        guard !didMigrate else { return false }

        let legacyProjects = loadLegacyProjects(from: projectsURL)
        let valuesByProject = readAllProjectSecretsFromKeychain()
        guard !valuesByProject.isEmpty else {
            markMigrated()
            return false
        }

        var migrated = false

        for pIdx in projects.indices {
            let projectID = projects[pIdx].id
            guard let projectValues = valuesByProject[projectID] else { continue }

            let legacySecrets = legacyProjects?.first(where: { $0.id == projectID })?.secrets ?? []
            let storageIDBySecretID = Dictionary(
                uniqueKeysWithValues: legacySecrets.map { ($0.id, $0.secretStorageID) }
            )

            for sIdx in projects[pIdx].secrets.indices {
                let secretID = projects[pIdx].secrets[sIdx].id
                let storageID = storageIDBySecretID[secretID]
                    ?? legacySecrets.first(where: { $0.id == secretID })?.secretStorageID

                guard let storageID, let value = projectValues[storageID], !value.isEmpty else { continue }
                projects[pIdx].secrets[sIdx].value = value
                migrated = true
            }
        }

        if migrated {
            deleteAllKeychainEntries(for: projects.map(\.id))
        }
        markMigrated()
        return migrated
    }

    static func deleteAllKeychainEntries(for projectIDs: [UUID]) {
        for projectID in projectIDs {
            deleteKeychainItem(account: projectAccount(for: projectID))
        }
    }

    // MARK: - Private

    private static func projectAccount(for projectID: UUID) -> String {
        "\(projectAccountPrefix)\(projectID.uuidString)"
    }

    private static func loadLegacyProjects(from url: URL) -> [LegacyProject]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([LegacyProject].self, from: data)
    }

    private static func readAllProjectSecretsFromKeychain() -> [UUID: [String: String]] {
        let allValues = readAllKeychainItems()
        var valuesByProject: [UUID: [String: String]] = [:]

        for (account, encodedPayload) in allValues where account.hasPrefix(projectAccountPrefix) {
            let projectIDString = String(account.dropFirst(projectAccountPrefix.count))
            guard
                let projectID = UUID(uuidString: projectIDString),
                let data = encodedPayload.data(using: .utf8),
                let payload = try? JSONDecoder().decode(ProjectSecretsPayload.self, from: data)
            else { continue }
            valuesByProject[projectID] = payload.valuesBySecretID
        }
        return valuesByProject
    }

    private static func readAllKeychainItems() -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let rows = item as? [[String: Any]] else { return [:] }

        var valuesByAccount: [String: String] = [:]
        for row in rows {
            guard
                let account = row[kSecAttrAccount as String] as? String,
                let data = row[kSecValueData as String] as? Data,
                let value = String(data: data, encoding: .utf8)
            else { continue }
            valuesByAccount[account] = value
        }
        return valuesByAccount
    }

    private static func deleteKeychainItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
