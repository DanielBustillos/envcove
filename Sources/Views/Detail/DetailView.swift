import SwiftUI
import AppKit

struct DetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: AppStore
    @State private var revealAllValues = false
    @State private var pendingDeleteSecret: SecretEntry?
    @State private var hoveredCardKey: String?
    @State private var newKeySheetSession: NewKeySheetSession?
    @State private var newProviderSheetSession: NewProviderSheetSession?
    @State private var collapsedProviders: Set<String> = []

    private var detailChromeBackground: Color {
        colorScheme == .dark
            ? Color(nsColor: .windowBackgroundColor)
            : Theme.windowToolbarBackground
    }

    /// Toolbar principal: provider name, generic title when no project, or nil when a project is open without a sidebar provider (no project name in the bar).
    private var detailToolbarPrincipalTitle: String? {
        if store.selectedSidebarProvider != nil {
            return nil
        }
        if store.selectedProjectIndex != nil {
            return nil
        }
        return "Secret Manager"
    }

    var body: some View {
        Group {
            if let providerName = store.selectedSidebarProvider {
                SidebarProviderDetailPanel(
                    providerName: providerName,
                    store: store,
                    revealAllValues: $revealAllValues,
                    collapsedProviders: $collapsedProviders,
                    hoveredCardKey: $hoveredCardKey,
                    pendingDeleteSecret: $pendingDeleteSecret,
                    newKeySheetSession: $newKeySheetSession
                )
            } else if let pIdx = store.selectedProjectIndex {
                let project = store.projects[pIdx]
                let providerGroups = providerGroups(from: project)
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 10) {
                            CupertinoMetricCard(
                                title: "Total keys",
                                primaryValue: "\(project.secrets.count)",
                                subtitle: "in \(project.name)",
                                iconSystemName: DashboardMetricTile.keysIcon,
                                iconTint: DashboardMetricTile.keysTint
                            )
                            CupertinoMetricCard(
                                title: "Providers",
                                primaryValue: "\(providerGroups.count)",
                                subtitle: "active",
                                iconSystemName: DashboardMetricTile.providersIcon,
                                iconTint: DashboardMetricTile.providersTint
                            )
                        }
                        .frame(maxHeight: DashboardMetrics.maxRowHeight)
                    }
                    .padding(UI.sectionPadding)
                    .background(ThemeCardBackground())

                    if project.secrets.isEmpty {
                        Spacer(minLength: 0)
                        HStack {
                            Spacer(minLength: 0)
                            EmptyProjectFirstKeyButton(isDisabled: authManager.isAuthenticating) {
                                newKeySheetSession = NewKeySheetSession(prefillProvider: nil, targetProjectID: project.id)
                            }
                            Spacer(minLength: 0)
                        }
                        Spacer(minLength: 0)
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(providerGroups, id: \.provider) { group in
                                    VStack(alignment: .leading, spacing: 8) {
                                        ProviderSectionHeader(
                                            store: store,
                                            providerName: group.provider,
                                            providerIcon: group.icon,
                                            isCollapsed: collapsedProviders.contains(group.provider),
                                            onToggleCollapse: {
                                                if collapsedProviders.contains(group.provider) {
                                                    collapsedProviders.remove(group.provider)
                                                } else {
                                                    collapsedProviders.insert(group.provider)
                                                }
                                            },
                                            onAddKey: {
                                                newKeySheetSession = NewKeySheetSession(prefillProvider: group.provider)
                                            },
                                            onDeleteProvider: {
                                                store.deleteProvider(name: group.provider)
                                            }
                                        )

                                        if !collapsedProviders.contains(group.provider) {
                                            let visibleSecrets = group.secrets.filter { !$0.isPlaceholder }
                                            if visibleSecrets.isEmpty {
                                                EmptyProviderCreateKeyButton {
                                                    newKeySheetSession = NewKeySheetSession(prefillProvider: group.provider)
                                                }
                                            } else {
                                                ForEach(visibleSecrets) { secret in
                                                    SecretRow(
                                                        store: store,
                                                        secret: secret,
                                                        currentProvider: (provider: group.provider, icon: group.icon),
                                                        revealValue: revealAllValues,
                                                        onChange: { newKey, newValue in
                                                            store.updateSecret(secret.id, key: newKey, value: newValue, provider: group.provider, providerIcon: group.icon)
                                                        },
                                                        onDeleteRequest: {
                                                            pendingDeleteSecret = secret
                                                        },
                                                        moveTargets: providerGroups
                                                            .filter { $0.provider != group.provider }
                                                            .map { (provider: $0.provider, icon: $0.icon) },
                                                        onMove: { targetProvider, targetIcon in
                                                            store.moveSecret(secret.id, toProvider: targetProvider, icon: targetIcon)
                                                        },
                                                        onCreateNewProviderAndMove: {
                                                            store.createProviderAndMoveSecret(secret.id)
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    .padding(UI.sectionPadding)
                                    .background(ThemeCardBackground())
                                    .overlay(
                                        RoundedRectangle(cornerRadius: UI.cornerRadius)
                                            .stroke(
                                                hoveredCardKey == group.provider
                                                ? Color.secondary.opacity(0.35)
                                                : Color.secondary.opacity(0.12),
                                                lineWidth: hoveredCardKey == group.provider ? 1.2 : 1
                                            )
                                    )
                                    .shadow(
                                        color: .black.opacity(hoveredCardKey == group.provider ? 0.06 : 0.0),
                                        radius: hoveredCardKey == group.provider ? 6 : 0,
                                        x: 0,
                                        y: 2
                                    )
                                    .onHover { hovering in
                                        hoveredCardKey = hovering ? group.provider : (hoveredCardKey == group.provider ? nil : hoveredCardKey)
                                    }
                                    .animation(.easeInOut(duration: UI.hoverAnimation), value: hoveredCardKey == group.provider)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                NotificationCenter.default.post(name: .dismissInlineEditors, object: nil)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .alert("Delete key", isPresented: Binding(
                    get: { pendingDeleteSecret != nil },
                    set: { if !$0 { pendingDeleteSecret = nil } }
                )) {
                    Button("Cancel", role: .cancel) {
                        pendingDeleteSecret = nil
                    }
                    Button("Delete", role: .destructive) {
                        if let secret = pendingDeleteSecret {
                            store.deleteSecrets(withIDs: [secret.id])
                        }
                        pendingDeleteSecret = nil
                    }
                } message: {
                    Text("This will delete the selected key.")
                }
                .sheet(item: $newKeySheetSession) { session in
                    NewKeySheetView(
                        store: store,
                        prefillProvider: session.prefillProvider,
                        targetProjectID: session.targetProjectID
                    )
                    .id(session.id)
                }
                .onChange(of: store.selectedProjectID) { _ in
                    collapsedProviders = []
                }
                .onChange(of: store.selectedSidebarProvider) { _ in
                    collapsedProviders = []
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.systemAccent.opacity(0.7), .secondary)
                    Text("No project selected")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: $newProviderSheetSession) { session in
            NewProviderSheetView(store: store)
                .id(session.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            detailChromeBackground
                .ignoresSafeArea(edges: .top)
        }
        .toolbar {
            if let title = detailToolbarPrincipalTitle {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .lineLimit(1)
                }
            }
            DetailToolbarContent(
                store: store,
                revealAllValues: $revealAllValues,
                newKeySheetSession: $newKeySheetSession,
                newProviderSheetSession: $newProviderSheetSession
            )
        }
    }
}

// MARK: - Window chrome configurator

/// Configures the key window for Sonoma-style split views: traffic lights sit over the sidebar, full-height column.
struct SonomaWindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.title = ""
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            window.toolbarStyle = .unified
            window.toolbar?.showsBaselineSeparator = false
        }
    }
}
