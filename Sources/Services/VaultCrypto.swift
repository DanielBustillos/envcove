import CryptoKit
import Foundation

struct VaultEnvelope: Codable {
    let version: Int
    let ciphertext: Data
}

enum VaultCrypto {
    static let currentVersion = 1

    static func generateDEK() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    static func encrypt(projects: [Project], key: SymmetricKey) throws -> Data {
        let plaintext = try JSONEncoder().encode(projects)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw VaultCryptoError.sealFailed
        }
        let envelope = VaultEnvelope(version: currentVersion, ciphertext: combined)
        return try JSONEncoder().encode(envelope)
    }

    static func decrypt(data: Data, key: SymmetricKey) throws -> [Project] {
        let envelope = try JSONDecoder().decode(VaultEnvelope.self, from: data)
        let sealedBox = try AES.GCM.SealedBox(combined: envelope.ciphertext)
        let plaintext = try AES.GCM.open(sealedBox, using: key)
        return try JSONDecoder().decode([Project].self, from: plaintext)
    }
}

enum VaultCryptoError: Error {
    case sealFailed
    case vaultFileMissing
}
