import SwiftUI

enum FinderColumn: Hashable, CaseIterable {
    case name
    case date
    case size
    case type
}

struct FinderColumnLayout: Equatable {
    var nameWidth: CGFloat = 280
    var dateWidth: CGFloat = 170
    var sizeWidth: CGFloat = 110
    var typeWidth: CGFloat = 120
    
    static let minWidth: CGFloat = 60
    static let maxWidth: CGFloat = 400
    
    func width(for column: FinderColumn) -> CGFloat {
        switch column {
        case .name: return nameWidth
        case .date: return dateWidth
        case .size: return sizeWidth
        case .type: return typeWidth
        }
    }
    
    func settingWidth(_ width: CGFloat, for column: FinderColumn) -> FinderColumnLayout {
        var copy = self
        let clamped = max(Self.minWidth, min(Self.maxWidth, width))
        switch column {
        case .name: copy.nameWidth = clamped
        case .date: copy.dateWidth = clamped
        case .size: copy.sizeWidth = clamped
        case .type: copy.typeWidth = clamped
        }
        return copy
    }
}

enum FinderLayoutConstants {
    static let trailingAccessoryWidth: CGFloat = 36
}

private struct FinderColumnLayoutKey: EnvironmentKey {
    static let defaultValue = FinderColumnLayout()
}

extension EnvironmentValues {
    var columnLayout: FinderColumnLayout {
        get { self[FinderColumnLayoutKey.self] }
        set { self[FinderColumnLayoutKey.self] = newValue }
    }
}
