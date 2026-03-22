import SwiftUI
import AppKit

struct SecretRow: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var store: AppStore
    let secret: SecretEntry
    let currentProvider: (provider: String, icon: String)
    let onChange: (String, String) -> Void
    let onDeleteRequest: () -> Void
    let moveTargets: [(provider: String, icon: String)]
    let onMove: (String, String) -> Void
    let onCreateNewProviderAndMove: () -> Void
    let revealValue: Bool

    @State private var justCopied = false
    @State private var justCopiedKey = false
    @State private var isHoveringRow = false
    @State private var isHoveringDelete = false
    @State private var isHoveringEdit = false
    @State private var isHoveringMove = false
    @State private var isEditSheetPresented = false

    private let actionColorNormal = Color.secondary.opacity(0.45)
    private let actionColorHover  = Color.primary.opacity(0.85)

    init(
        store: AppStore,
        secret: SecretEntry,
        currentProvider: (provider: String, icon: String),
        revealValue: Bool,
        onChange: @escaping (String, String) -> Void,
        onDeleteRequest: @escaping () -> Void,
        moveTargets: [(provider: String, icon: String)],
        onMove: @escaping (String, String) -> Void,
        onCreateNewProviderAndMove: @escaping () -> Void
    ) {
        self.store = store
        self.secret = secret
        self.currentProvider = currentProvider
        self.revealValue = revealValue
        self.onChange = onChange
        self.onDeleteRequest = onDeleteRequest
        self.moveTargets = moveTargets
        self.onMove = onMove
        self.onCreateNewProviderAndMove = onCreateNewProviderAndMove
    }

    private func copyKeyToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(secret.key, forType: .string)
        justCopiedKey = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justCopiedKey = false }
    }

    private func copyValueToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(secret.value, forType: .string)
        let changeCount = NSPasteboard.general.changeCount
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justCopied = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if NSPasteboard.general.changeCount == changeCount {
                NSPasteboard.general.clearContents()
            }
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(secret.key)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: UI.fieldCornerRadius)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(alignment: .trailing) {
                    if isHoveringRow {
                        Button { copyKeyToPasteboard() } label: {
                            StandardSymbolImage(systemName: justCopiedKey ? "checkmark.circle.fill" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .padding(.trailing, 6)
                        .help(justCopiedKey ? "Name copied" : "Copy name")
                    }
                }
                .highPriorityGesture(TapGesture(count: 2).onEnded { _ in isEditSheetPresented = true })
                .onTapGesture { copyKeyToPasteboard() }

            Text(revealValue ? secret.value : UI.maskedSecretDisplay(for: secret.value))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: UI.fieldCornerRadius)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(alignment: .trailing) {
                    if isHoveringRow {
                        Button { copyValueToPasteboard() } label: {
                            StandardSymbolImage(systemName: justCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .padding(.trailing, 6)
                        .help(justCopied ? "Value copied" : "Copy value")
                    }
                }
                .highPriorityGesture(TapGesture(count: 2).onEnded { _ in isEditSheetPresented = true })
                .onTapGesture { copyValueToPasteboard() }

            HStack(spacing: 6) {
                Button { onDeleteRequest() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: UI.rowActionIconPointSize, weight: .medium))
                        .frame(width: UI.inlineActionWidth, height: UI.inlineActionHeight)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isHoveringDelete ? actionColorHover : actionColorNormal)
                .help("Delete key")
                .onHover { isHoveringDelete = $0 }
                .animation(.easeInOut(duration: UI.hoverAnimation), value: isHoveringDelete)

                Button { isEditSheetPresented = true } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: UI.rowActionIconPointSize, weight: .medium))
                        .frame(width: UI.inlineActionWidth, height: UI.inlineActionHeight)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isHoveringEdit ? actionColorHover : actionColorNormal)
                .help("Edit key")
                .onHover { isHoveringEdit = $0 }
                .animation(.easeInOut(duration: UI.hoverAnimation), value: isHoveringEdit)

                Menu {
                    Button {
                        onMove(currentProvider.provider, currentProvider.icon)
                    } label: {
                        Label(currentProvider.provider, systemImage: currentProvider.icon)
                    }
                    Divider()
                    if moveTargets.isEmpty {
                        Text("No other providers")
                    } else {
                        ForEach(moveTargets, id: \.provider) { target in
                            Button {
                                onMove(target.provider, target.icon)
                            } label: {
                                Label(target.provider, systemImage: target.icon)
                            }
                        }
                    }
                    Divider()
                    Button("Create new provider") { onCreateNewProviderAndMove() }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: UI.rowActionIconPointSize, weight: .medium))
                        .frame(width: UI.inlineActionWidth, height: UI.inlineActionHeight)
                        .foregroundStyle(isHoveringMove ? actionColorHover : actionColorNormal)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("Move to another provider")
                .onHover { isHoveringMove = $0 }
                .animation(.easeInOut(duration: UI.hoverAnimation), value: isHoveringMove)
            }
            .frame(width: UI.rowTrailingActionClusterWidth, alignment: .center)
            .opacity(isHoveringRow ? 1 : 0)
            .allowsHitTesting(isHoveringRow)
            .animation(.easeInOut(duration: UI.hoverAnimation), value: isHoveringRow)
        }
        .contentShape(Rectangle())
        .onHover { isHoveringRow = $0 }
        .padding(.vertical, 2)
        .sheet(isPresented: $isEditSheetPresented) {
            EditKeySheetView(
                store: store,
                secretID: secret.id,
                initialKey: secret.key,
                initialValue: secret.value,
                initialProvider: currentProvider.provider
            )
        }
    }
}

// MARK: - Modal button styles

private struct NewKeyModalSaveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.84, blue: 0.08))
            )
            .foregroundStyle(.black.opacity(configuration.isPressed ? 0.65 : 1))
    }
}

private struct NewKeyModalCancelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .foregroundStyle(.primary.opacity(configuration.isPressed ? 0.65 : 1))
    }
}

// MARK: - Modal form primitives

private struct ModalFormDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.12))
            .frame(height: 1)
    }
}

private struct ModalFormRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            content()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct ModalFormCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 20)
    }
}

private struct ModalSheetHeader: View {
    let systemImage: String
    let title: String
    var iconPointSize: CGFloat = 24

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.92))
                    .frame(width: 58, height: 58)
                Image(systemName: systemImage)
                    .font(.system(size: iconPointSize, weight: .medium))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.yellow, .mint, .cyan)
            }
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.top, 22)
        .padding(.bottom, 18)
    }
}

private struct ModalSheetChrome<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.bottom, 8)
        .frame(minWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 28, x: 0, y: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        )
        .padding(20)
    }
}

private struct ModalSheetFooter: View {
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top, 8)
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Button("Cancel", action: onCancel)
                    .buttonStyle(NewKeyModalCancelButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .buttonStyle(NewKeyModalSaveButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
        }
    }
}

// MARK: - Edit key sheet

private struct EditKeySheetView: View {
    @ObservedObject var store: AppStore
    let secretID: SecretEntry.ID
    let initialKey: String
    let initialValue: String
    let initialProvider: String
    @Environment(\.dismiss) private var dismiss

    @State private var nameDraft = ""
    @State private var keyDraft = ""
    @State private var providerDraft = ""
    @State private var revealKeyInEditSheet = false
    @State private var justCopiedEditName = false
    @State private var justCopiedEditKey = false

    private var trimmedName: String { nameDraft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedProvider: String { providerDraft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && !trimmedProvider.isEmpty }

    private func copyNameToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(nameDraft, forType: .string)
        justCopiedEditName = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            justCopiedEditName = false
        }
    }

    private func copyKeyToPasteboardFromSheet() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(keyDraft, forType: .string)
        let changeCount = NSPasteboard.general.changeCount
        justCopiedEditKey = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justCopiedEditKey = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if NSPasteboard.general.changeCount == changeCount {
                NSPasteboard.general.clearContents()
            }
        }
    }

    var body: some View {
        ModalSheetChrome {
            ModalSheetHeader(systemImage: "square.and.pencil", title: "Edit key")
            ModalFormCard {
                VStack(spacing: 0) {
                    ModalFormRow(label: "Name") {
                        HStack(spacing: 8) {
                            TextField("OPENAI_API_KEY", text: $nameDraft)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity)
                            Button {
                                copyNameToPasteboard()
                            } label: {
                                StandardSymbolImage(systemName: justCopiedEditName ? "checkmark.circle.fill" : "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .help(justCopiedEditName ? "Copied" : "Copy name")
                        }
                    }
                    ModalFormDivider()
                    ModalFormRow(label: "Key") {
                        HStack(spacing: 8) {
                            Group {
                                if revealKeyInEditSheet {
                                    TextField("", text: $keyDraft)
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.trailing)
                                } else {
                                    SecureField("", text: $keyDraft)
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            Button {
                                revealKeyInEditSheet.toggle()
                            } label: {
                                Image(systemName: revealKeyInEditSheet ? "eye.slash" : "eye")
                                    .font(.system(size: UI.rowActionIconPointSize, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(revealKeyInEditSheet ? "Hide value" : "Show value")
                            Button {
                                copyKeyToPasteboardFromSheet()
                            } label: {
                                StandardSymbolImage(systemName: justCopiedEditKey ? "checkmark.circle.fill" : "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .help(justCopiedEditKey ? "Copied" : "Copy value")
                        }
                    }
                    ModalFormDivider()
                    ModalFormRow(label: "Provider") {
                        TextField("OpenAI", text: $providerDraft)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            ModalSheetFooter(
                canSave: canSave,
                onCancel: { dismiss() },
                onSave: {
                    let icon = providerPresets.first(where: { $0.name.caseInsensitiveCompare(trimmedProvider) == .orderedSame })?.icon ?? "network"
                    store.updateSecret(secretID, key: trimmedName, value: keyDraft, provider: trimmedProvider, providerIcon: icon)
                    dismiss()
                }
            )
        }
        .onAppear {
            nameDraft = initialKey
            keyDraft = initialValue
            providerDraft = initialProvider
        }
    }
}

// MARK: - Sheet session identifiers

struct NewKeySheetSession: Identifiable {
    let id = UUID()
    var prefillProvider: String?
    /// When set, the new secret is added to this project instead of the currently selected one.
    var targetProjectID: Project.ID? = nil
}

struct NewProviderSheetSession: Identifiable {
    let id = UUID()
}

// MARK: - New key sheet

struct NewKeySheetView: View {
    @ObservedObject var store: AppStore
    var prefillProvider: String?
    var targetProjectID: Project.ID? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var nameDraft = ""
    @State private var keyDraft = ""
    @State private var providerDraft = ""
    @State private var newProviderNestedSheet: NewProviderSheetSession?
    @State private var keyVisible = false

    private var trimmedName: String { nameDraft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedProvider: String { providerDraft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && !trimmedProvider.isEmpty }

    private var targetProject: Project? {
        if let pid = targetProjectID {
            return store.projects.first(where: { $0.id == pid })
        }
        guard let idx = store.selectedProjectIndex else { return nil }
        return store.projects[idx]
    }

    private var selectableProviderNames: [String] {
        let presetNames = providerPresets.map(\.name)
        guard let project = targetProject else {
            return presetNames.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }
        let existing = Set(providerGroups(from: project).map(\.provider))
        let combined = existing.union(presetNames)
        return combined.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        ModalSheetChrome {
            ModalSheetHeader(systemImage: "key.fill", title: "New key", iconPointSize: 26)
            ModalFormCard {
                VStack(spacing: 0) {
                    ModalFormRow(label: "Name") {
                        TextField("OPENAI_API_KEY", text: $nameDraft)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                    }
                    ModalFormDivider()
                    ModalFormRow(label: "Key") {
                        HStack(spacing: 6) {
                            Group {
                                if keyVisible {
                                    TextField("", text: $keyDraft)
                                } else {
                                    SecureField("", text: $keyDraft)
                                }
                            }
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity)
                            Button {
                                keyVisible.toggle()
                            } label: {
                                Image(systemName: keyVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(keyVisible ? "Hide key" : "Show key")
                        }
                    }
                    ModalFormDivider()
                    ModalFormRow(label: "Provider") {
                        Menu {
                            ForEach(selectableProviderNames, id: \.self) { name in
                                Button(name) {
                                    providerDraft = name
                                }
                            }
                            Divider()
                            Button("New provider…") {
                                newProviderNestedSheet = NewProviderSheetSession()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(providerDraft.isEmpty ? "Choose provider" : providerDraft)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }
                }
            }
            ModalSheetFooter(
                canSave: canSave,
                onCancel: { dismiss() },
                onSave: {
                    store.addSecret(named: trimmedName, secretValue: keyDraft, provider: trimmedProvider, projectID: targetProjectID)
                    dismiss()
                }
            )
        }
        .onAppear {
            if let prefillProvider {
                providerDraft = prefillProvider
            }
        }
        .sheet(item: $newProviderNestedSheet) { session in
            NewProviderSheetView(store: store) { name in
                providerDraft = name
            }
            .id(session.id)
        }
    }
}

// MARK: - Provider icon picker

let providerIconOptions: [String] = [
    "network", "cloud.fill", "server.rack", "cylinder.fill",
    "lock.fill", "shield.fill", "key.fill", "globe",
    "arrow.triangle.2.circlepath", "curlybraces", "terminal.fill", "gearshape.fill",
    "bolt.fill", "flame.fill", "leaf.fill", "person.fill",
    "building.2.fill", "envelope.fill", "externaldrive.fill", "cpu.fill",
    "antenna.radiowaves.left.and.right", "icloud.fill", "rectangle.connected.to.line.below", "link",
    "creditcard.fill", "cart.fill", "bag.fill", "checkmark.seal.fill",
    "doc.fill", "folder.fill", "tray.fill", "archivebox.fill",
    "mappin.circle.fill", "star.fill", "tag.fill", "bookmark.fill",
]

struct ProviderIconPickerPopover: View {
    @Binding var selected: String
    @Binding var isPresented: Bool

    private let columns = Array(repeating: GridItem(.fixed(36), spacing: 6), count: 6)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(providerIconOptions, id: \.self) { symbol in
                    Button {
                        selected = symbol
                        isPresented = false
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selected == symbol
                                      ? Color.accentColor.opacity(0.18)
                                      : Color(nsColor: .controlBackgroundColor))
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(selected == symbol ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            Image(systemName: symbol)
                                .font(.system(size: 16, weight: .medium))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(selected == symbol ? Color.accentColor : Color.primary)
                        }
                        .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .help(symbol)
                }
            }
            .padding(10)
        }
        .frame(width: 262, height: 200)
    }
}

// MARK: - New provider sheet

struct NewProviderSheetView: View {
    @ObservedObject var store: AppStore
    /// Called with the new provider display name after a successful save (e.g. to preselect in New key).
    var onProviderCreated: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var nameDraft = ""
    @State private var iconDraft = "network"
    @State private var showIconPicker = false

    init(store: AppStore, onProviderCreated: ((String) -> Void)? = nil) {
        self.store = store
        self.onProviderCreated = onProviderCreated
    }

    private var trimmedName: String { nameDraft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty }

    private var resolvedIcon: String {
        if let preset = providerPresets.first(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            return preset.icon
        }
        return iconDraft
    }

    var body: some View {
        ModalSheetChrome {
            ModalSheetHeader(systemImage: resolvedIcon, title: "New provider")
            ModalFormCard {
                VStack(spacing: 0) {
                    ModalFormRow(label: "Name") {
                        TextField("My API", text: $nameDraft)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    ModalFormDivider()
                    ModalFormRow(label: "Icon") {
                        Button {
                            showIconPicker.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Spacer()
                                Text(resolvedIcon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Image(systemName: resolvedIcon)
                                    .font(.system(size: 14, weight: .medium))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.primary)
                                    .frame(width: 20)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showIconPicker, arrowEdge: .bottom) {
                            ProviderIconPickerPopover(selected: $iconDraft, isPresented: $showIconPicker)
                        }
                    }
                }
            }
            ModalSheetFooter(
                canSave: canSave,
                onCancel: { dismiss() },
                onSave: {
                    let name = trimmedName
                    store.addProvider(name: name, icon: resolvedIcon)
                    onProviderCreated?(name)
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Dashboard components

enum DashboardMetricTile {
    static let keysIcon = "key.fill"
    /// Mockup yellow (#F4C348)
    static let keysTint = Color(red: 244 / 255, green: 195 / 255, blue: 72 / 255)
    static let providersIcon = "square.grid.2x2"
    /// Mockup light blue (#6AB1DA)
    static let providersTint = Color(red: 106 / 255, green: 177 / 255, blue: 218 / 255)
    static let projectsIcon = "folder.fill"
    /// Same family as providers tile for the project-count card in provider detail.
    static let projectsTint = Color(red: 106 / 255, green: 177 / 255, blue: 218 / 255)
}

enum DashboardMetrics {
    /// Summary row must not exceed 5% of main display height.
    static var maxRowHeight: CGFloat {
        (NSScreen.main?.frame.height ?? 900) * 0.05
    }
}

struct EmptyProjectFirstKeyButton: View {
    var isDisabled: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text("Create first key")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isDisabled ? Color.secondary.opacity(0.45) : Color.primary.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovering && !isDisabled ? 1 : 0.88))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(isHovering && !isDisabled ? 0.28 : 0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: UI.hoverAnimation), value: isHovering)
        .help("Add a secret key to this project")
    }
}

struct EmptyProviderCreateKeyButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12, weight: .medium))
                Text("Create key")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isHovering ? Color.primary : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.9 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(isHovering ? 0.25 : 0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: UI.hoverAnimation), value: isHovering)
        .help("Add a key to this provider")
    }
}

/// Compact dashboard tile: single horizontal strip (icon, labels, value) to stay within `DashboardMetrics.maxRowHeight`.
struct CupertinoMetricCard: View {
    let title: String
    let primaryValue: String
    let subtitle: String
    let iconSystemName: String
    let iconTint: Color
    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        primaryValue: String,
        subtitle: String,
        iconSystemName: String,
        iconTint: Color
    ) {
        self.title = title
        self.primaryValue = primaryValue
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.iconTint = iconTint
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconTint)
                    .frame(width: 24, height: 24)
                Image(systemName: iconSystemName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.monochrome)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(minWidth: 0, alignment: .leading)

            Spacer(minLength: 4)

            Text(primaryValue)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: colorScheme == .dark ? 0.75 : 0.32))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardFill)
        )
        .clipped()
    }

    private var cardFill: Color {
        if colorScheme == .dark {
            Color(nsColor: .controlBackgroundColor).opacity(0.92)
        } else {
            Color(red: 238 / 255, green: 238 / 255, blue: 238 / 255)
        }
    }
}
