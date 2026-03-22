# .envCove

A native macOS app for managing API keys and secrets, organized by project and provider. All secret values are stored exclusively in the macOS Keychain and access is gated behind Touch ID / biometric authentication.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)

---

## Features

- **Touch ID lock screen** — the app requires biometric authentication on launch. Sensitive operations (revealing values, exporting) require re-authentication.
- **Projects** — organize secrets into multiple named workspaces.
- **Providers** — group secrets within a project by provider (OpenAI, AWS, GitHub, Stripe, etc.) with SF Symbol icons.
- **Dashboard** — per-project cards showing total key count and provider count.
- **Sidebar navigation** — browse by project or filter by provider across all projects.
- **Masked values** — secret values are always hidden behind `•••••••••` until explicitly revealed.
- **Reveal / hide all** — toolbar toggle to show all values at once (requires Touch ID).
- **Copy to clipboard** — hover over a row to reveal copy buttons.
- **Add / Edit / Delete** — full CRUD for secrets, providers, and projects.
- **Inline renaming** — double-click a project or provider to rename it in place.
- **Move secrets** — reassign a secret to a different provider via context menu.
- **Collapsible provider sections** — keep the detail view clean.
- **Export `.env`** — saves all keys as `KEY=VALUE` lines (Touch ID required).
- **Import `.env`** — parses `.env` files, including `export KEY=VALUE` syntax, quoted values, and comments.
- **Export JSON** (`⌘⇧E`) — structured JSON export with project, provider, key, and value (Touch ID required).
- **Import JSON** (`⌘⇧I`) — re-import a previously exported JSON file into any project (Touch ID required).
- **Custom provider icons** — pick from 36 SF Symbol options for custom providers.

---

## Security Model

SecretManager deliberately separates **metadata** from **secret values**:

| What | Where stored |
|---|---|
| Project names, key names, provider info | `~/Library/Application Support/SecretManager/projects.json` |
| Secret values | macOS **Keychain** only — never written to disk in plaintext |

Secret values are loaded into memory only after a successful Touch ID authentication and are flushed back to the Keychain whenever the app goes to background or terminates.

Value masking uses a fixed-length string (`•••••••••`) regardless of the actual secret length to avoid leaking length information.

---

## Built-in Providers

| Provider | | Provider | |
|---|---|---|---|
| OpenAI | ✓ | Stripe | ✓ |
| Anthropic | ✓ | Twilio | ✓ |
| Google AI | ✓ | Mapbox | ✓ |
| AWS | ✓ | Supabase | ✓ |
| Azure | ✓ | Custom | ✓ |
| GitHub | ✓ | | |

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
| `AppStore` | `@MainActor ObservableObject` | Single source of truth; all state and mutation logic |
| `AuthManager` | `@MainActor ObservableObject` | Biometric auth via `LocalAuthentication` |
| `KeychainStore` | `struct` | Wraps `Security` framework; one Keychain blob per project |
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
│   ├── Services/       — AppStore, AuthManager, KeychainStore
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
- `Security`

No Swift Package Manager packages, CocoaPods, or Carthage.

---

## Getting Started

1. Clone the repository.
2. Open `envCove.xcodeproj` in Xcode (or regenerate it with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate`).
3. Select the `SecretManager` scheme and your Mac as the run destination.
4. Build and run (`⌘R`).

No additional setup is required — the app creates its data directory automatically on first launch.

---

## License

This project is released under the [MIT License](LICENSE).
