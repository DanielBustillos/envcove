import Foundation

enum AppSupportMigration {
    static let folderName = "envCove"
    static let legacyFolderName = "SecretManager"
    static let vaultFileName = "projects.vault"
    static let plaintextFileName = "projects.json"
    private static let encryptedVaultFlagKey = "didMigrateToEncryptedVault"

    static var didMigrateToEncryptedVault: Bool {
        UserDefaults.standard.bool(forKey: encryptedVaultFlagKey)
    }

    static func markEncryptedVaultMigrated() {
        UserDefaults.standard.set(true, forKey: encryptedVaultFlagKey)
    }

    static func appSupportFolder() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(folderName, isDirectory: true)
    }

    static func vaultURL(in folder: URL) -> URL {
        folder.appendingPathComponent(vaultFileName)
    }

    static func plaintextURL(in folder: URL) -> URL {
        folder.appendingPathComponent(plaintextFileName)
    }

    /// Moves `SecretManager/` to `envCove/` if the legacy folder exists.
    static func migrateAppSupportFolderIfNeeded() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        let legacy = appSupport.appendingPathComponent(legacyFolderName, isDirectory: true)
        let current = appSupport.appendingPathComponent(folderName, isDirectory: true)

        if FileManager.default.fileExists(atPath: legacy.path) {
            if FileManager.default.fileExists(atPath: current.path) {
                mergeContents(from: legacy, into: current)
                try? FileManager.default.removeItem(at: legacy)
            } else {
                try? FileManager.default.moveItem(at: legacy, to: current)
            }
        }

        try? FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
    }

    static func loadPlaintextProjects(from url: URL) -> [Project]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Project].self, from: data)
    }

    // MARK: - Private

    private static func mergeContents(from source: URL, into destination: URL) {
        guard let items = try? FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) else {
            return
        }

        for item in items {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if FileManager.default.fileExists(atPath: target.path) { continue }
            try? FileManager.default.moveItem(at: item, to: target)
        }
    }
}
