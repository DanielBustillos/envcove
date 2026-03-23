import SwiftUI

struct ProviderSectionHeader: View {
    @ObservedObject var store: AppStore
    let providerName: String
    let providerIcon: String
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onAddKey: () -> Void
    let onDeleteProvider: () -> Void
    @State private var isEditingName = false
    @State private var isEditingIcon = false
    @State private var isHoveringHeader = false
    @State private var isHoveringDelete = false
    @State private var showDeleteConfirm = false
    @State private var draftName: String
    @State private var draftIcon: String
    @FocusState private var isProviderNameFocused: Bool

    init(
        store: AppStore,
        providerName: String,
        providerIcon: String,
        isCollapsed: Bool,
        onToggleCollapse: @escaping () -> Void,
        onAddKey: @escaping () -> Void,
        onDeleteProvider: @escaping () -> Void
    ) {
        self.store = store
        self.providerName = providerName
        self.providerIcon = providerIcon
        self.isCollapsed = isCollapsed
        self.onToggleCollapse = onToggleCollapse
        self.onAddKey = onAddKey
        self.onDeleteProvider = onDeleteProvider
        _draftName = State(initialValue: providerName)
        _draftIcon = State(initialValue: providerIcon)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                onToggleCollapse()
            } label: {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 20, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand" : "Collapse")

            StandardSymbolImage(
                systemName: providerIcon,
                pointSize: UI.providerHeaderIconPointSize,
                weight: .medium,
                style: .hierarchical
            )
                .foregroundStyle(isHoveringHeader ? Color.primary : Color.secondary)
                .onTapGesture(count: 2) {
                    isEditingIcon.toggle()
                }
                .popover(isPresented: $isEditingIcon, arrowEdge: .bottom) {
                    ProviderIconPickerPopover(selected: $draftIcon, isPresented: $isEditingIcon)
                }
                .onChange(of: draftIcon) { newIcon in
                    store.updateProviderIcon(providerName: providerName, icon: newIcon)
                }
                .help("Double-click to edit icon")

            if isEditingName {
                TextField("Provider", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150, alignment: .leading)
                    .focused($isProviderNameFocused)
                    .onSubmit {
                        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            store.renameProvider(oldName: providerName, newName: trimmed)
                        }
                        isEditingName = false
                    }
                    .onAppear {
                        DispatchQueue.main.async { isProviderNameFocused = true }
                    }
            } else {
                Text(providerName)
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .onTapGesture(count: 2) {
                        draftName = providerName
                        isEditingName = true
                    }
                    .help("Double-click to edit name")
            }

            if isEditingName {
                Button {
                    let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        store.renameProvider(oldName: providerName, newName: trimmed)
                    }
                    isEditingName = false
                } label: {
                    StandardSymbolImage(systemName: "checkmark.circle.fill", pointSize: UI.providerHeaderIconPointSize)
                }
                .buttonStyle(.borderless)
                .help("Save name")
            } else {
                EmptyView()
            }

            Spacer(minLength: 0)

            if isHoveringHeader && !isEditingName {
                Button {
                    showDeleteConfirm = true
                } label: {
                    StandardSymbolImage(systemName: "trash", pointSize: UI.providerHeaderIconPointSize)
                        .foregroundStyle(isHoveringDelete ? Color.red : Color.secondary.opacity(0.45))
                }
                .buttonStyle(.borderless)
                .help("Delete provider")
                .onHover { isHoveringDelete = $0 }
                .animation(.easeInOut(duration: UI.hoverAnimation), value: isHoveringDelete)
            }

            Button {
                onAddKey()
            } label: {
                StandardSymbolImage(systemName: "plus.circle", pointSize: UI.providerHeaderIconPointSize)
            }
            .buttonStyle(.borderless)
            .help("Add key")
        }
        .frame(minHeight: 26, alignment: .center)
        .confirmationDialog(
            "Delete \"\(providerName)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Provider and All Its Keys", role: .destructive) {
                onDeleteProvider()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all keys under this provider.")
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 1)
        }
        .onHover { hovering in
            isHoveringHeader = hovering
        }
        .animation(.easeInOut(duration: UI.hoverAnimation), value: isHoveringHeader)
        .onChange(of: isProviderNameFocused) { isFocused in
            if !isFocused, isEditingName {
                isEditingName = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissInlineEditors)) { _ in
            isProviderNameFocused = false
            isEditingName = false
            isEditingIcon = false
        }
    }
}

// MARK: - Detail toolbar

struct DetailToolbarContent: ToolbarContent {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var store: AppStore
    @Binding var revealAllValues: Bool
    @Binding var newKeySheetSession: NewKeySheetSession?
    @Binding var newProviderSheetSession: NewProviderSheetSession?
    private var toolbarDisabled: Bool {
        store.selectedProjectIndex == nil || authManager.isAuthenticating
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            ControlGroup {
                Button {
                    Task {
                        let ok = await authManager.authenticate(reason: "Re-authenticate to reload your secrets.")
                        if ok {
                            store.reauthenticateWithKeychain(context: authManager.context)
                        }
                    }
                } label: {
                    Label("Re-authenticate", systemImage: "lock.open.rotation")
                }
                .help("Re-authenticate with Keychain")

                Button {
                    if revealAllValues {
                        revealAllValues = false
                    } else if authManager.isUnlocked {
                        revealAllValues = true
                    } else {
                        Task {
                            let ok = await authManager.authenticate(reason: "Authenticate to reveal saved secrets.")
                            if ok {
                                revealAllValues = true
                            }
                        }
                    }
                } label: {
                    Label(revealAllValues ? "Hide values" : "Show values",
                          systemImage: revealAllValues ? "eye.slash" : "eye")
                }
                .help(revealAllValues ? "Hide values" : "Show values")
            }
            .disabled(toolbarDisabled)
        }

        ToolbarItem(placement: .automatic) {
            ControlGroup {
                Button {
                    Task {
                        let ok = await authManager.authenticate(reason: "Authenticate to export the .env file.")
                        if ok {
                            store.exportSelectedProjectAsEnv()
                        }
                    }
                } label: {
                    Label("Export .env", systemImage: "arrow.up.document")
                }
                .help("Export .env")

                Button {
                    store.importEnvIntoSelectedProject()
                } label: {
                    Label("Import .env", systemImage: "arrow.down.document")
                }
                .help("Import .env")
            }
            .disabled(toolbarDisabled)
        }

        ToolbarItem(placement: .automatic) {
            ControlGroup {
                Button {
                    newProviderSheetSession = NewProviderSheetSession()
                } label: {
                    Label("Add provider", systemImage: "text.pad.header.badge.plus")
                }
                .help("Add provider")

                Button {
                    newKeySheetSession = NewKeySheetSession(prefillProvider: nil)
                } label: {
                    Label("Add key", systemImage: "key.shield")
                }
                .help("Add key")
            }
            .disabled(toolbarDisabled)
        }
    }
}

// MARK: - Sidebar provider detail panel

struct SidebarProviderDetailPanel: View {
    let providerName: String
    @ObservedObject var store: AppStore
    @Binding var revealAllValues: Bool
    @Binding var collapsedProviders: Set<String>
    @Binding var hoveredCardKey: String?
    @Binding var pendingDeleteSecret: SecretEntry?
    @Binding var newKeySheetSession: NewKeySheetSession?

    private func projectChunks() -> [(Project, (provider: String, icon: String, secrets: [SecretEntry]))] {
        store.projects.compactMap { p in
            let groups = providerGroups(from: p)
            guard let g = groups.first(where: { $0.provider == providerName }) else { return nil }
            return (p, g)
        }
    }

    private func collapseKey(project: Project, provider: String) -> String {
        "\(project.id.uuidString)|\(provider)"
    }

    var body: some View {
        let chunks = projectChunks()
        let totalKeys = chunks.reduce(0) { $0 + $1.1.secrets.count }
        Group {
            if chunks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.systemAccent.opacity(0.7), .secondary)
                    Text("No keys for \"\(providerName)\"")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(providerName)
                            .font(.title3.weight(.semibold))

                        HStack(alignment: .center, spacing: 10) {
                            CupertinoMetricCard(
                                title: "Total keys",
                                primaryValue: "\(totalKeys)",
                                subtitle: "across \(chunks.count) projects",
                                iconSystemName: DashboardMetricTile.keysIcon,
                                iconTint: DashboardMetricTile.keysTint
                            )
                            CupertinoMetricCard(
                                title: "Projects",
                                primaryValue: "\(chunks.count)",
                                subtitle: "with this provider",
                                iconSystemName: DashboardMetricTile.projectsIcon,
                                iconTint: DashboardMetricTile.projectsTint
                            )
                        }
                        .frame(maxHeight: DashboardMetrics.maxRowHeight)
                    }
                    .padding(UI.sectionPadding)
                    .background(ThemeCardBackground())

                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(chunks, id: \.0.id) { project, group in
                                chunkCard(project: project, group: group)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            NotificationCenter.default.post(name: .dismissInlineEditors, object: nil)
                        }
                    }
                }
                .padding()
            }
        }
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
    }

    @ViewBuilder
    private func chunkCard(project: Project, group: (provider: String, icon: String, secrets: [SecretEntry])) -> some View {
        let ck = collapseKey(project: project, provider: group.provider)
        let groupsInProject = providerGroups(from: project)
        VStack(alignment: .leading, spacing: 8) {
            Text(project.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            ProviderSectionHeader(
                store: store,
                providerName: group.provider,
                providerIcon: group.icon,
                isCollapsed: collapsedProviders.contains(ck),
                onToggleCollapse: {
                    if collapsedProviders.contains(ck) {
                        collapsedProviders.remove(ck)
                    } else {
                        collapsedProviders.insert(ck)
                    }
                },
                onAddKey: {
                    newKeySheetSession = NewKeySheetSession(
                        prefillProvider: group.provider,
                        targetProjectID: project.id
                    )
                },
                onDeleteProvider: {
                    store.deleteProvider(name: group.provider, projectID: project.id)
                }
            )

            if !collapsedProviders.contains(ck) {
                let visibleSecrets = group.secrets.filter { !$0.isPlaceholder }
                if visibleSecrets.isEmpty {
                    EmptyProviderCreateKeyButton {
                        newKeySheetSession = NewKeySheetSession(
                            prefillProvider: group.provider,
                            targetProjectID: project.id
                        )
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
                            moveTargets: groupsInProject
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
                    hoveredCardKey == ck
                    ? Color.secondary.opacity(0.35)
                    : Color.secondary.opacity(0.12),
                    lineWidth: hoveredCardKey == ck ? 1.2 : 1
                )
        )
        .shadow(
            color: .black.opacity(hoveredCardKey == ck ? 0.06 : 0.0),
            radius: hoveredCardKey == ck ? 6 : 0,
            x: 0,
            y: 2
        )
        .onHover { hovering in
            hoveredCardKey = hovering ? ck : (hoveredCardKey == ck ? nil : hoveredCardKey)
        }
        .animation(.easeInOut(duration: UI.hoverAnimation), value: hoveredCardKey == ck)
    }
}
