import SwiftUI

struct ProjectRow: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    let project: Project
    @ObservedObject var store: AppStore
    /// Active project row (no provider selected in sidebar).
    var isSidebarProjectSelected: Bool = false

    @State private var isEditingName = false
    @State private var draftName: String
    @State private var showDeleteConfirmation = false
    @FocusState private var isNameFieldFocused: Bool

    init(project: Project, store: AppStore, isSidebarProjectSelected: Bool = false) {
        self.project = project
        self.store = store
        self.isSidebarProjectSelected = isSidebarProjectSelected
        _draftName = State(initialValue: project.name)
    }

    private func saveRename() {
        store.renameProject(project.id, to: draftName)
        isEditingName = false
    }

    var body: some View {
        Group {
            if isEditingName {
                HStack(alignment: .center, spacing: 6) {
                    TextField("Project name", text: $draftName)
                        .textFieldStyle(.plain)
                        .focused($isNameFieldFocused)
                        .onSubmit {
                            saveRename()
                        }
                        .onAppear {
                            DispatchQueue.main.async { isNameFieldFocused = true }
                        }
                    Button {
                        saveRename()
                    } label: {
                        StandardSymbolImage(systemName: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Confirm rename")
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: SecretManagerChrome.sidebarRowIconSize, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(
                            isSidebarProjectSelected
                                ? Color(nsColor: .controlAccentColor)
                                : SecretManagerChrome.sidebarSecondaryIcon(colorScheme)
                        )
                    Text(project.name)
                        .font(.system(
                            size: SecretManagerChrome.sidebarRowFontSize,
                            weight: isSidebarProjectSelected ? .semibold : .regular
                        ))
                        .foregroundStyle(
                            isSidebarProjectSelected
                                ? Color(nsColor: .controlAccentColor)
                                : Color(nsColor: .labelColor)
                        )
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.trailing, SecretManagerChrome.sidebarProjectRowDotTrailingInset)
                .frame(maxWidth: .infinity, minHeight: SecretManagerChrome.sidebarRowMinHeight, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    draftName = project.name
                    isEditingName = true
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        store.selectProjectOnly(project.id)
                    }
                )
            }
        }
        .onChange(of: isNameFieldFocused) { isFocused in
            if !isFocused, isEditingName {
                isEditingName = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissInlineEditors)) { _ in
            isNameFieldFocused = false
            isEditingName = false
        }
        .contextMenu {
            Button("Rename") {
                draftName = project.name
                isEditingName = true
            }
            Button("Export .env") {
                Task {
                    let ok = await authManager.authenticate(reason: "Authenticate to export the .env file.")
                    if ok {
                        store.exportProjectAsEnv(projectID: project.id)
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .alert("Delete project?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteProject(project.id)
            }
        } message: {
            Text("This will delete the project and all saved secrets in it.")
        }
    }
}
