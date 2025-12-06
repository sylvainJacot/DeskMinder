import Foundation
import SwiftUI

enum FinderColumn: String, Hashable, CaseIterable, Codable {
    case name
    case date
    case size
    case type
}

struct FinderColumnLayout: Codable, Equatable {
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

struct FinderColumnPreferences: Codable {
    var layout: FinderColumnLayout
    var order: [FinderColumn]
    
    private static let defaultsKey = "FinderColumnPreferences"
    
    static func load() -> FinderColumnPreferences {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: defaultsKey),
           var prefs = try? JSONDecoder().decode(FinderColumnPreferences.self, from: data) {
            prefs.order = sanitized(order: prefs.order)
            return prefs
        }
        return FinderColumnPreferences(
            layout: FinderColumnLayout(),
            order: Array(FinderColumn.allCases)
        )
    }
    
    func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
    
    private static func sanitized(order: [FinderColumn]) -> [FinderColumn] {
        var unique: [FinderColumn] = []
        for column in order where !unique.contains(column) {
            unique.append(column)
        }
        for column in FinderColumn.allCases where !unique.contains(column) {
            unique.append(column)
        }
        return unique
    }
}

enum FinderLayoutConstants {
    static let trailingAccessoryWidth: CGFloat = 36
}

private struct FinderColumnLayoutKey: EnvironmentKey {
    static let defaultValue = FinderColumnLayout()
}

private struct FinderColumnOrderKey: EnvironmentKey {
    static let defaultValue = Array(FinderColumn.allCases)
}

extension EnvironmentValues {
    var finderColumnLayout: FinderColumnLayout {
        get { self[FinderColumnLayoutKey.self] }
        set { self[FinderColumnLayoutKey.self] = newValue }
    }
    
    var finderColumnOrder: [FinderColumn] {
        get { self[FinderColumnOrderKey.self] }
        set { self[FinderColumnOrderKey.self] = newValue }
    }
}
