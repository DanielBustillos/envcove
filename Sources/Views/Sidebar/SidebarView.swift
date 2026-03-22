import SwiftUI

private struct ProviderSidebarOutlineItem: Identifiable {
    let id: String
    let provider: String
    let icon: String
}

@MainActor
private func providerSidebarOutline(from store: AppStore) -> [ProviderSidebarOutlineItem] {
    let allNames = Set(store.projects.flatMap { $0.secrets.map(\.provider) })
    let sorted = allNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    return sorted.compactMap { prov in
        let hasSecrets = store.projects.contains { p in
            p.secrets.contains { $0.provider == prov }
        }
        guard hasSecrets else { return nil }
        let icon = store.projects
            .flatMap(\.secrets)
            .first(where: { $0.provider == prov })?.providerIcon ?? "network"
        return ProviderSidebarOutlineItem(id: prov, provider: prov, icon: icon)
    }
}

struct SidebarView: View {
    @ObservedObject var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    private var providerOutline: [ProviderSidebarOutlineItem] {
        providerSidebarOutline(from: store)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                SidebarSectionHeader(title: "PROJECTS", showAddButton: true, onAdd: { store.addProject() })
                    .padding(.top, 8)

                ForEach(store.projects) { project in
                    let projectSelected = store.selectedProjectID == project.id && store.selectedSidebarProvider == nil
                    ProjectRow(project: project, store: store, isSidebarProjectSelected: projectSelected)
                        .padding(.vertical, SecretManagerChrome.sidebarRowVerticalPadding)
                        .padding(.horizontal, SecretManagerChrome.sidebarRowInnerHorizontalPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: SecretManagerChrome.selectionPillRadius, style: .continuous)
                                .fill(projectSelected ? SecretManagerChrome.sidebarSelectionBackground : Color.clear)
                        )
                        .padding(.vertical, 2)
                }

                SidebarSectionHeader(title: "PROVIDERS", showAddButton: false)
                    .padding(.top, SecretManagerChrome.providersSectionExtraTop)

                if providerOutline.isEmpty {
                    Text("No providers yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(providerOutline) { item in
                        let providerSelected = store.selectedSidebarProvider == item.provider
                        Button {
                            store.selectSidebarProvider(item.provider)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.icon)
                                    .font(.system(size: SecretManagerChrome.sidebarRowIconSize, weight: .medium))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(
                                        providerSelected
                                            ? Color(nsColor: .controlAccentColor)
                                            : SecretManagerChrome.sidebarSecondaryIcon(colorScheme)
                                    )
                                Text(item.provider)
                                    .font(.system(
                                        size: SecretManagerChrome.sidebarRowFontSize,
                                        weight: providerSelected ? .semibold : .regular
                                    ))
                                    .foregroundStyle(
                                        providerSelected
                                            ? Color(nsColor: .controlAccentColor)
                                            : Color(nsColor: .labelColor)
                                    )
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: SecretManagerChrome.sidebarRowMinHeight, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, SecretManagerChrome.sidebarRowVerticalPadding)
                        .padding(.horizontal, SecretManagerChrome.sidebarRowInnerHorizontalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: SecretManagerChrome.selectionPillRadius, style: .continuous)
                                .fill(providerSelected ? SecretManagerChrome.sidebarSelectionBackground : Color.clear)
                        )
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.leading, UI.sidebarOuterPaddingHorizontal)
            .padding(.trailing, UI.sidebarOuterPaddingTrailing)
            .padding(.bottom, UI.sidebarOuterPaddingBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, UI.sidebarOuterPaddingTop)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Rectangle()
                .fill(SecretManagerChrome.sidebarPanelBackground(colorScheme))
                .ignoresSafeArea(edges: .top)
        }
    }
}
