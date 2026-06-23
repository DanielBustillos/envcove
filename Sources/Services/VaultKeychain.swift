import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum VaultKeychainError: Error, LocalizedError {
    case storeFailed(OSStatus)
    case loadFailed(OSStatus)
    case invalidKeyData

    var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "Could not store the encryption key in Keychain (status \(status))."
        case .loadFailed(let status):
            return "Could not read the encryption key from Keychain (status \(status))."
        case .invalidKeyData:
            return "The encryption key in Keychain is invalid."
        }
    }
}

enum VaultKeychain {
    private static let service = "com.daniel.secretmanager"
    private static let account = "vault-dek"

    /// Loads the DEK from Keychain. App-level Touch ID (AuthManager) is the gate before this is called.
    static func loadDEK(context _: LAContext) throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw VaultKeychainError.loadFailed(status)
        }
        guard data.count == 32 else { throw VaultKeychainError.invalidKeyData }
        return SymmetricKey(data: data)
    }

    /// Stores the DEK in Keychain without SecAccessControl (avoids errSecMissingEntitlement -34018
    /// with ad-hoc signing). App-level Touch ID remains the authentication gate.
    static func storeDEK(_ key: SymmetricKey, context _: LAContext) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        guard keyData.count == 32 else { throw VaultKeychainError.invalidKeyData }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: keyData] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            deleteDEK()
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = keyData
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw VaultKeychainError.storeFailed(status)
            }
            return
        }

        // Legacy item may have incompatible attributes — delete and re-add.
        deleteDEK()
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = keyData
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultKeychainError.storeFailed(status)
        }
    }

    static func deleteDEK() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
