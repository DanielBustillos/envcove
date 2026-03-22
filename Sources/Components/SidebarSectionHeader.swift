import SwiftUI

struct SidebarSectionHeader: View {
    let title: String
    var showAddButton: Bool = false
    var onAdd: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(.system(size: SecretManagerChrome.sidebarSectionHeaderFontSize, weight: .semibold))
                .foregroundStyle(SecretManagerChrome.sidebarSectionHeaderColor)
                .tracking(0.3)
            Spacer(minLength: 0)
            if showAddButton {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.borderless)
                .help("New project")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, SecretManagerChrome.sectionHeaderBottomSpacing)
    }
}
