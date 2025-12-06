import SwiftUI
import AppKit

struct DesktopItemRow: View {
    let item: DesktopItem
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onFocus: () -> Void
    let isFocused: Bool
    let isIgnored: Bool
    let onToggleIgnored: () -> Void
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: item.lastModified)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggleSelection()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            
            FileThumbnailView(url: item.url)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                
                Text("Modifié le \(formattedDate) (\(item.formattedFileSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                VStack(alignment: .trailing) {
                    Text("\(item.daysOld) j")
                        .font(.headline)
                        .foregroundColor(item.daysOld > 30 ? .red : .primary)
                    
                    Text("sur le bureau")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Button(action: onToggleIgnored) {
                    Image(systemName: isIgnored ? "star.fill" : "star")
                        .foregroundColor(isIgnored ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(isIgnored ? "Autoriser à nouveau le rangement" : "Ne jamais proposer de ranger ce fichier")
            }
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                onFocus()
            }
        )
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            Button("Afficher dans le Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            
            Divider()
            
            Button(isIgnored ? "Autoriser à nouveau le rangement" : "Ne jamais proposer de ranger ce fichier") {
                onToggleIgnored()
            }
            
            Button("Sélectionner") {
                onToggleSelection()
            }
        }
        .padding(.vertical, 4)
    }
}

