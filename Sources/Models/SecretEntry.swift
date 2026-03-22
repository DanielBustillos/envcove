import Foundation

struct SecretEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var key: String
    var value: String
    var provider: String
    var providerIcon: String
    var secretStorageID: String
    /// True for the synthetic entry that keeps an empty provider alive in the data model.
    var isPlaceholder: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, key, value, provider, providerIcon, secretStorageID, isPlaceholder
    }

    init(
        id: UUID = UUID(),
        key: String,
        value: String,
        provider: String = "OpenAI",
        providerIcon: String = "network",
        secretStorageID: String = UUID().uuidString,
        isPlaceholder: Bool = false
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.provider = provider
        self.providerIcon = providerIcon
        self.secretStorageID = secretStorageID
        self.isPlaceholder = isPlaceholder
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(key, forKey: .key)
        try container.encode(provider, forKey: .provider)
        try container.encode(providerIcon, forKey: .providerIcon)
        try container.encode(secretStorageID, forKey: .secretStorageID)
        if isPlaceholder { try container.encode(true, forKey: .isPlaceholder) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        key = try container.decode(String.self, forKey: .key)
        value = ""  // never persisted in projects.json; real value comes from Keychain
        provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? "Custom"
        providerIcon = try container.decodeIfPresent(String.self, forKey: .providerIcon) ?? "network"
        secretStorageID = try container.decodeIfPresent(String.self, forKey: .secretStorageID) ?? UUID().uuidString
        isPlaceholder = try container.decodeIfPresent(Bool.self, forKey: .isPlaceholder) ?? false
    }
}
