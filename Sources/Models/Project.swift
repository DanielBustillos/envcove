import Foundation

struct Project: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var secrets: [SecretEntry] = []
    /// Updated when project data is persisted after edits.
    var lastModified: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id, name, secrets, lastModified
    }

    init(
        id: UUID = UUID(),
        name: String,
        secrets: [SecretEntry] = [],
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.secrets = secrets
        self.lastModified = lastModified
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        secrets = try c.decodeIfPresent([SecretEntry].self, forKey: .secrets) ?? []
        lastModified = try c.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(secrets, forKey: .secrets)
        try c.encode(lastModified, forKey: .lastModified)
    }
}

func providerGroups(from project: Project) -> [(provider: String, icon: String, secrets: [SecretEntry])] {
    let providerOrder = Array(Set(project.secrets.map(\.provider))).sorted {
        $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
    }
    return providerOrder.map { providerName in
        let items = project.secrets.filter { $0.provider == providerName }
        return (provider: providerName, icon: items.first?.providerIcon ?? "network", secrets: items)
    }
}
