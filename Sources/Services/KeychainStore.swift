import Foundation
import Security
import LocalAuthentication

struct ProjectSecretsPayload: Codable {
    var version: Int = 1
    var valuesBySecretID: [String: String]
}

struct KeychainStore {
    let service: String
    static let projectAccountPrefix = "project:"

    static func projectAccount(for projectID: UUID) -> String {
        "\(projectAccountPrefix)\(projectID.uuidString)"
    }

    // MARK: - Write

    /// Stores `value` under `id`.
    ///
    /// Items are marked `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: encrypted at rest,
    /// readable only when the device screen is unlocked, never backed up or migrated.
    /// App-level Touch ID (AuthManager) is the authentication gate; we intentionally avoid
    /// kSecAttrAccessControl + .userPresence because macOS batch reads (kSecMatchLimitAll)
    /// fail silently for access-control-protected items.
    func set(id: String, value: String) -> Bool {
        let data = Data(value.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id
        ]

        // Try in-place update first (preserves any existing accessibility attribute).
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }

        // Item doesn't exist yet — add it with the accessibility attribute.
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }

        // Item exists but update was blocked (e.g. legacy item with kSecAttrAccessControl +
        // .userPresence that requires authentication to modify). Delete and re-add without
        // access control so the app-level Touch ID gate handles protection instead.
        SecItemDelete(baseQuery as CFDictionary)
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Read (single item)

    func get(id: String, context: LAContext? = nil, prompt: String? = nil) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let context {
            query[kSecUseAuthenticationContext as String] = context
        } else if let prompt {
            let ctx = LAContext()
            ctx.localizedReason = prompt
            query[kSecUseAuthenticationContext as String] = ctx
        }

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Read (all items for this service)

    func getAll(context: LAContext? = nil, prompt: String? = nil) -> [String: String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        if let context {
            query[kSecUseAuthenticationContext as String] = context
        } else if let prompt {
            let ctx = LAContext()
            ctx.localizedReason = prompt
            query[kSecUseAuthenticationContext as String] = ctx
        }

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let rows = item as? [[String: Any]] else { return [:] }

        var valuesByID: [String: String] = [:]
        for row in rows {
            guard
                let account = row[kSecAttrAccount as String] as? String,
                let data = row[kSecValueData as String] as? Data,
                let value = String(data: data, encoding: .utf8)
            else { continue }
            valuesByID[account] = value
        }
        return valuesByID
    }

    // MARK: - Delete

    func delete(id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Project-level helpers

    func setProjectSecrets(projectID: UUID, valuesBySecretID: [String: String]) -> Bool {
        let payload = ProjectSecretsPayload(valuesBySecretID: valuesBySecretID)
        guard
            let data = try? JSONEncoder().encode(payload),
            let encoded = String(data: data, encoding: .utf8)
        else { return false }
        return set(id: Self.projectAccount(for: projectID), value: encoded)
    }

    func getProjectSecrets(projectID: UUID, context: LAContext? = nil, prompt: String? = nil) -> [String: String]? {
        guard
            let encoded = get(id: Self.projectAccount(for: projectID), context: context, prompt: prompt),
            let data = encoded.data(using: .utf8),
            let payload = try? JSONDecoder().decode(ProjectSecretsPayload.self, from: data)
        else { return nil }
        return payload.valuesBySecretID
    }

    func getAllProjectSecrets(context: LAContext? = nil, prompt: String? = nil) -> [UUID: [String: String]] {
        let allValues = getAll(context: context, prompt: prompt)
        var valuesByProject: [UUID: [String: String]] = [:]

        for (account, encodedPayload) in allValues where account.hasPrefix(Self.projectAccountPrefix) {
            let projectIDString = String(account.dropFirst(Self.projectAccountPrefix.count))
            guard
                let projectID = UUID(uuidString: projectIDString),
                let data = encodedPayload.data(using: .utf8),
                let payload = try? JSONDecoder().decode(ProjectSecretsPayload.self, from: data)
            else { continue }
            valuesByProject[projectID] = payload.valuesBySecretID
        }
        return valuesByProject
    }

    func deleteProjectSecrets(projectID: UUID) {
        delete(id: Self.projectAccount(for: projectID))
    }
}
