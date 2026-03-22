import SwiftUI

enum UI {
    static let cornerRadius: CGFloat = 10
    static let fieldCornerRadius: CGFloat = 8
    static let sectionPadding: CGFloat = 12
    static let rowSpacing: CGFloat = 10
    static let inlineActionWidth: CGFloat = 24
    static let inlineActionHeight: CGFloat = 24
    /// Fixed width for delete / edit / move on each secret row so fields don't resize on hover.
    static let rowTrailingActionClusterWidth: CGFloat = 92
    static let rowActionIconPointSize: CGFloat = 13
    static let providerHeaderIconPointSize: CGFloat = 17
    static let sidebarIconPointSize: CGFloat = 15
    /// Extra inset below the system safe area; keep small so the sidebar reads as one column under transparent toolbar.
    static let sidebarOuterPaddingTop: CGFloat = 0
    static let sidebarOuterPaddingHorizontal: CGFloat = 8
    /// Extra trailing inset so row badges are not clipped by the split column edge.
    static let sidebarOuterPaddingTrailing: CGFloat = 14
    static let sidebarOuterPaddingBottom: CGFloat = 12
    /// Horizontal insets for list rows and section headers (balances left padding and selection width).
    static let sidebarListRowLeading: CGFloat = 12
    static let sidebarListRowTrailing: CGFloat = 12
    /// Fixed-width mask when the secret is hidden (does not reveal stored length).
    static func maskedSecretDisplay(for value: String) -> String {
        guard !value.isEmpty else { return "" }
        return String(repeating: "•", count: 9)
    }
    static let hoverAnimation: Double = 0.16
}

/// Sidebar + toolbar chrome (SecretManager reference: neutral selection, accent dot, unified toolbar).
enum SecretManagerChrome {
    static let sidebarSectionHeaderFontSize: CGFloat = 11
    static let sidebarRowFontSize: CGFloat = 13
    static let sidebarRowIconSize: CGFloat = 13
    static let selectionPillRadius: CGFloat = 6
    static let sidebarRowMinHeight: CGFloat = 26
    static let sidebarRowInnerHorizontalPadding: CGFloat = 10
    static let sidebarRowVerticalPadding: CGFloat = 5
    static let sectionHeaderBottomSpacing: CGFloat = 6
    static let providersSectionExtraTop: CGFloat = 14
    /// Extra inset so the project accent dot is not clipped at the sidebar column edge.
    static let sidebarProjectRowDotTrailingInset: CGFloat = 8
    static let appDisplayName = ".envCove"

    static var sidebarSectionHeaderColor: Color { Color(nsColor: .tertiaryLabelColor) }

    /// Selection fill: #F5F5F5 in light mode, a subtle dark fill in dark mode.
    static var sidebarSelectionBackground: Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.22, alpha: 1)
                : NSColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)
        })
    }

    /// Left sidebar column background in light mode (#FBFBFB).
    static let sidebarPanelBackgroundLight = Color(red: 251 / 255, green: 251 / 255, blue: 251 / 255)

    static func sidebarPanelBackground(_ scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return Color(nsColor: .windowBackgroundColor)
        case .light:
            fallthrough
        @unknown default:
            return sidebarPanelBackgroundLight
        }
    }

    static func sidebarSecondaryIcon(_ scheme: ColorScheme) -> Color {
        Color(nsColor: .secondaryLabelColor)
    }
}
