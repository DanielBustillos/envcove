import SwiftUI

struct ThemeCardBackground: View {
    var cornerRadius: CGFloat = UI.cornerRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(NSColor.controlBackgroundColor))
    }
}
