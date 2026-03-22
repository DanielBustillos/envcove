import SwiftUI

struct StandardSymbolImage: View {
    enum Style {
        case plain
        case hierarchical
        case monochrome
    }

    let systemName: String
    var pointSize: CGFloat
    var weight: Font.Weight
    var style: Style
    var cellWidth: CGFloat
    var cellHeight: CGFloat

    init(
        systemName: String,
        pointSize: CGFloat = UI.rowActionIconPointSize,
        weight: Font.Weight = .medium,
        style: Style = .plain,
        cellWidth: CGFloat = UI.inlineActionWidth,
        cellHeight: CGFloat = UI.inlineActionHeight
    ) {
        self.systemName = systemName
        self.pointSize = pointSize
        self.weight = weight
        self.style = style
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
    }

    var body: some View {
        Group {
            switch style {
            case .plain:
                Image(systemName: systemName)
                    .font(.system(size: pointSize, weight: weight))
                    .imageScale(.medium)
            case .hierarchical:
                Image(systemName: systemName)
                    .font(.system(size: pointSize, weight: weight))
                    .imageScale(.medium)
                    .symbolRenderingMode(.hierarchical)
            case .monochrome:
                Image(systemName: systemName)
                    .font(.system(size: pointSize, weight: weight))
                    .imageScale(.medium)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .frame(width: cellWidth, height: cellHeight)
    }
}
