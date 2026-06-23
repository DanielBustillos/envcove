# envCove Reference

## Storage layout

| Path | Contents |
|------|----------|
| `~/Library/Application Support/envCove/projects.vault` | AES-GCM encrypted `[Project]` envelope |
| Keychain `vault-dek` | 256-bit DEK, biometric-protected |

Legacy paths migrated automatically:
- `SecretManager/` → `envCove/`
- `projects.json` (plaintext) → `projects.vault` on first unlock

## Lifecycle

```
Launch → projects = [] (no decrypt before Touch ID)

Touch ID OK
  → AuthManager.context set
  → AppStore.unlock(context:)
      → load/create DEK from Keychain
      → decrypt projects.vault OR migrate plaintext JSON

Lock
  → save() (encrypt with DEK)
  → lock() (clear DEK + projects from memory)

Background / quit → save() if unlocked
```

## VaultEnvelope

```swift
struct VaultEnvelope: Codable {
    let version: Int      // 1
    let ciphertext: Data  // AES.GCM.SealedBox.combined
}
```

## Source file inventory

| File | Responsibility |
|------|----------------|
| `VaultCrypto.swift` | AES-GCM encrypt/decrypt |
| `VaultKeychain.swift` | DEK load/store/delete in Keychain |
| `AppSupportMigration.swift` | Folder rename, plaintext migration helpers |
| `KeychainMigration.swift` | Legacy per-project Keychain secrets migration |
| `AppStore.swift` | unlock/lock/save, CRUD, import/export |

## Known gaps

- DEK is device-bound (no cross-Mac vault transfer without JSON export)
- No test target or CI
