import SwiftUI

struct RootView: View {
    @StateObject private var store = AppStore()
    @StateObject private var authManager = AuthManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var splitColumnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if authManager.isUnlocked {
                NavigationSplitView(columnVisibility: $splitColumnVisibility) {
                    SidebarView(store: store)
                        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
                } detail: {
                    DetailView(store: store)
                }
                /// Transparent so the left column's sidebar material runs through the toolbar strip (above the white detail fill).
                .toolbarBackground(.hidden, for: .windowToolbar)
                .environmentObject(authManager)
                .task {
                    store.prepareSecretsFromKeychainIfNeeded(context: authManager.context)
                }
            } else {
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    RadialGradient(
                        colors: [
                            Theme.systemAccent.opacity(0.14),
                            Theme.systemAccent.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 420
                    )
                    VStack(spacing: 16) {
                        Image(systemName: "touchid")
                            .font(.system(size: 44))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Theme.systemAccent)
                        Text("Unlock .envCove")
                            .font(.headline)
                        if let error = authManager.lastErrorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Button(authManager.isAuthenticating ? "Authenticating..." : "Unlock with Touch ID") {
                            Task {
                                _ = await authManager.authenticate(reason: "Unlock .envCove to access your secrets.")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(authManager.isAuthenticating)
                    }
                    .padding(32)
                    .tint(Color(nsColor: .controlAccentColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .focusedSceneValue(\.appStore, store)
        .focusedSceneValue(\.appAuthManager, authManager)
        .background(SonomaWindowChromeConfigurator())
        .frame(minWidth: 900, minHeight: 580)
        .task {
            if !authManager.isUnlocked {
                _ = await authManager.authenticate(reason: "Unlock .envCove to access your secrets.")
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .inactive || phase == .background {
                store.flushAllProjectsToKeychain(context: authManager.context)
            }
        }
        .onChange(of: authManager.isUnlocked) { unlocked in
            if !unlocked {
                store.clearSecretsFromMemory()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.flushAllProjectsToKeychain(context: authManager.context)
        }
    }
}
