import SwiftUI

struct IgnoreToggleButton: View {
    @ObservedObject var scanner: DesktopScanner
    let item: DesktopItem
    
    var body: some View {
        Button {
            scanner.toggleIgnored(item)
        } label: {
            Image(systemName: scanner.isIgnored(item) ? "star.fill" : "star")
                .imageScale(.small)
                .foregroundColor(scanner.isIgnored(item) ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
        .help(
            scanner.isIgnored(item)
            ? "Remove from Ignored — show this file in cleanup suggestions again"
            : "Ignore this item — it will no longer appear in cleanup suggestions"
        )
    }
}