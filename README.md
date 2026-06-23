# .envCove


<p align="center">
  <img src="Assets.xcassets/icon.appiconset/icon_secret-macOS-Default-512x512@1x.png" width="300" height="300">
</p>


A native macOS app for managing API keys and secrets, organized by project and provider. All data is stored locally in JSON and access is gated behind Touch ID / biometric authentication.

[![Website](https://img.shields.io/badge/website-live-brightgreen)](https://danielbustillos.github.io/envcove/)
![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)





---

## Features

- **Touch ID lock screen** — the app requires biometric authentication on launch. Sensitive operations (revealing values, exporting) require re-authentication.
- **Projects/Providers** — organize secrets into multiple named workspaces or API providers.
- **Dashboard** — per-project cards showing total key count and provider count.
- **Reveal / hide all** — toolbar toggle to show all values at once (requires Touch ID).
- **Copy to clipboard** — hover over a row to reveal copy buttons.
- **Add / Edit / Delete** — full CRUD for secrets, providers, and projects.
- **Export and import `.env`** — saves all keys as `KEY=VALUE` lines (Touch ID required).
- **Export import JSON** (`⌘⇧E`) — structured JSON export with project, provider, key, and value (Touch ID required).
- **Custom provider icons** — pick from 36 SF Symbol options for custom providers.


![image](docs/assets/screenshot-main.png)
---

## Security Model

Project data is stored in an **encrypted vault** on disk. A 256-bit Data Encryption Key (DEK) lives in the macOS Keychain, protected by Touch ID.

| What | Where stored |
|---|---|
| Encrypted vault (projects, keys, values) | `~/Library/Application Support/envCove/projects.vault` |
| Data Encryption Key | macOS Keychain (`vault-dek`, biometric-protected) |

Touch ID unlocks the DEK and decrypts the vault into memory. When the app locks, in-memory data is cleared. Sensitive operations (reveal, export) require re-authentication.

Value masking uses a fixed-length string (`•••••••••`) regardless of the actual secret length to avoid leaking length information.

> **Note:** The DEK is bound to this Mac's biometrics and does not transfer to other devices. Use JSON export as a portable backup.


---

## Requirements

- macOS 13.0 (Ventura) or later
- Mac with Touch ID (or a paired Apple Watch for authentication)
- Xcode 15+

---

## Architecture

The app follows a **single-store, reactive pattern** with unidirectional data flow.

```
SecretManagerApp (@main)
└── RootView                  — auth gate + NavigationSplitView
    ├── SidebarView           — Projects & Providers lists
    └── DetailView            — Secret rows, sheets (add/edit/import/export)
```

| Layer | Type | Role |
|---|---|---|
| `AppStore` | `@MainActor ObservableObject` | Single source of truth; vault encrypt/decrypt, import/export |
| `AuthManager` | `@MainActor ObservableObject` | Biometric auth via `LocalAuthentication` |
| `VaultCrypto` | `enum` | AES-GCM encryption of project data |
| `VaultKeychain` | `enum` | DEK storage in Keychain with biometrics |
| `AppSupportMigration` | `enum` | Folder rename + plaintext-to-vault migration |
| `KeychainMigration` | `enum` | One-time migration from legacy Keychain storage |
| Models | `Codable struct` | `Project`, `SecretEntry`, `ProviderPreset`, `ExportModels` |
| Views | `SwiftUI View` | Observe `AppStore`; receive `AuthManager` via `@EnvironmentObject` |

---

## Project Structure

```
secret_manager/
├── envCove.xcodeproj/
├── Sources/
│   ├── App/            — entry point, root view, scene lifecycle
│   ├── Components/     — reusable UI primitives
│   ├── Models/         — Codable data types
│   ├── Services/       — AppStore, AuthManager, VaultCrypto, VaultKeychain
│   ├── Theme/          — design tokens and color palette
│   ├── Utilities/      — notifications, debug logger
│   └── Views/
│       ├── Detail/     — main pane, provider headers, secret rows
│       └── Sidebar/    — project list, provider filter list
├── Assets.xcassets/
├── docs/               — static marketing/landing page
├── project.yml         — XcodeGen project definition
└── Info.plist
```

---

## Dependencies

**None.** Only Apple system frameworks are used:

- `SwiftUI` / `AppKit`
- `Foundation`
- `LocalAuthentication`
- `CryptoKit`
- `Security`

No Swift Package Manager packages, CocoaPods, or Carthage.

---

## Getting Started

### Option A — Download the app (recommended)

1. Go to the [Releases page](https://github.com/DanielBustillos/envcove/releases).
2. Download the latest `.app` from the Assets section.
3. Move `.envCove.app` to your `/Applications` folder and open it.

> macOS may show a security prompt on first launch. Go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Option B — Build from source

1. Clone the repository.
2. Open `envCove.xcodeproj` in Xcode (or regenerate it with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate`).
3. Select the `SecretManager` scheme and your Mac as the run destination.
4. Build and run (`⌘R`).

No additional setup is required — the app creates its data directory automatically on first launch.

---

## License

This project is released under the [MIT License](LICENSE).
