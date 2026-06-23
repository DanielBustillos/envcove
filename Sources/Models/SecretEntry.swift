import Foundation

struct SecretEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var key: String
    var value: String
    var provider: String
    var providerIcon: String
    /// True for the synthetic entry that keeps an empty provider alive in the data model.
    var isPlaceholder: Bool = false

    init(
        id: UUID = UUID(),
        key: String,
        value: String,
        provider: String = "OpenAI",
        providerIcon: String = "network",
        isPlaceholder: Bool = false
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.provider = provider
        self.providerIcon = providerIcon
        self.isPlaceholder = isPlaceholder
    }
}
