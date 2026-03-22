import SwiftUI

// MARK: - Focused value keys for menu commands

private struct AppStoreFocusedKey: FocusedValueKey {
    typealias Value = AppStore
}

private struct AuthManagerFocusedKey: FocusedValueKey {
    typealias Value = AuthManager
}

extension FocusedValues {
    var appStore: AppStore? {
        get { self[AppStoreFocusedKey.self] }
        set { self[AppStoreFocusedKey.self] = newValue }
    }
    var appAuthManager: AuthManager? {
        get { self[AuthManagerFocusedKey.self] }
        set { self[AuthManagerFocusedKey.self] = newValue }
    }
}

// MARK: - File menu commands

private struct FileCommands: Commands {
    @FocusedValue(\.appStore) private var store: AppStore?
    @FocusedValue(\.appAuthManager) private var authManager: AuthManager?

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Divider()
            Button("Import Project from JSON...") {
                Task {
                    guard let auth = authManager, let s = store else { return }
                    let ok = await auth.authenticate(reason: "Authenticate to import a project from JSON.")
                    if ok { s.importProjectFromJSON() }
                }
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            Button("Export Project as JSON...") {
                Task {
                    guard let auth = authManager, let s = store else { return }
                    let ok = await auth.authenticate(reason: "Authenticate to export the project with secrets as JSON.")
                    if ok { s.exportSelectedProjectAsJSON() }
                }
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}

// MARK: - App entry point

@main
struct SecretManagerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            FileCommands()
        }
    }
}
