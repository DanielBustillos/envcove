---
name: envcove
description: >-
  Develop the envCove macOS secrets app (SwiftUI, envCove target).
  Use when working on envCove, SwiftUI views, AppStore, VaultCrypto,
  VaultKeychain, project.yml, or macOS secret management features.
---

# envCove Development

## Quick context

- **App**: local macOS vault for API keys and secrets, organized by **project** and **provider**
- **Stack**: Swift 5.9, SwiftUI, AppKit bridges, Apple frameworks only
- **Constraints**: no SPM/CocoaPods/Carthage, no test target, no CI
- **Platform**: macOS 13+ (Ventura), Touch ID required for full auth flows
- **Storage**: encrypted `projects.vault` + DEK in Keychain (`~/Library/Application Support/envCove/`)

## Naming split

| Layer | Name |
|-------|------|
| UI / marketing | `.envCove` or `envCove` |
| Xcode target / scheme | `envCove` |
| Bundle ID | `com.daniel.secretmanager` |
| App Support folder | `envCove` |
| Repo directory | `envCove` |

## Architecture

```
SecretManagerApp (@main)
└── RootView                  — auth gate + NavigationSplitView
    ├── AppStore              — vault encrypt/decrypt (@StateObject)
    └── AuthManager           — Touch ID + LAContext (@EnvironmentObject)
```

| Layer | File | Role |
|-------|------|------|
| Store | `Sources/Services/AppStore.swift` | CRUD, unlock/lock/save, import/export |
| Auth | `Sources/Services/AuthManager.swift` | Biometric auth, LAContext for DEK |
| Crypto | `Sources/Services/VaultCrypto.swift` | AES-GCM seal/open |
| Keychain | `Sources/Services/VaultKeychain.swift` | DEK in Keychain (biometry) |
| Migration | `Sources/Services/AppSupportMigration.swift` | Folder + plaintext migration |

### Development rules

1. **All data mutations go through `AppStore`** — views must not mutate `projects` directly
2. **`AppStore.unlock(context:)`** only after Touch ID; **`lock()`** clears DEK + memory
3. **`save()`** requires DEK in memory — blocked while locked
4. Pass **`AppStore`** as `@ObservedObject`; inject **`AuthManager`** via `@EnvironmentObject`
5. No external dependencies unless explicitly requested

## Edit map

| Task | File(s) |
|------|---------|
| Vault crypto | `Sources/Services/VaultCrypto.swift` |
| DEK Keychain | `Sources/Services/VaultKeychain.swift` |
| Store lifecycle | `Sources/Services/AppStore.swift` |
| Migrations | `Sources/Services/AppSupportMigration.swift`, `KeychainMigration.swift` |
| Auth / unlock flow | `Sources/Services/AuthManager.swift`, `Sources/App/RootView.swift` |

## Build

```bash
xcodegen generate
xcodebuild -project envCove.xcodeproj -scheme envCove -configuration Debug build
```

## Security guardrails

1. Never persist decrypted projects to disk — only `projects.vault` (AES-GCM)
2. DEK only in Keychain with `SecAccessControl(.biometryCurrentSet)`
3. `unlock(context:)` must receive the `LAContext` from successful auth
4. On lock: `save()` then `lock()`; on unlock: `unlock(context:)`
5. Export JSON is intentionally plaintext (portable backup)

## Additional resources

See [reference.md](reference.md).
