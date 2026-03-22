import Foundation

struct ProjectKeysExport: Codable {
    let projectName: String
    let items: [ProjectKeyExportItem]
}

struct ProjectKeyExportItem: Codable {
    let provider: String
    let key: String
    let secret: String
}
