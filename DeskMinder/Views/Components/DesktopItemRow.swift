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
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.finderColumnLayout) private var columnLayout
    @Environment(\.finderColumnOrder) private var columnOrder
    @State private var isHovered = false
    
    private var formattedDate: String {
        Self.dateFormatter.string(from: item.lastModified)
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private var titleColor: Color {
        isSelected ? .white : .primary
    }
    
    private var metadataColor: Color {
        isSelected ? Color.white.opacity(0.85) : Color.secondary
    }
    
    private var selectionBackground: Color {
        guard isSelected else { return .clear }
        return colorScheme == .dark
            ? Color.accentColor.opacity(0.55)
            : Color.accentColor.opacity(0.9)
    }
    
    private var hoverBackground: Color {
        guard !isSelected else { return .clear }
        let baseOpacity = colorScheme == .dark ? 0.25 : 0.07
        return Color.primary.opacity(isHovered ? baseOpacity : 0)
    }
    
    private var focusBorderColor: Color {
        guard isFocused else { return .clear }
        return colorScheme == .dark ? Color.accentColor.opacity(0.8) : Color.accentColor.opacity(0.6)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(columnOrder, id: \.self) { column in
                columnView(for: column)
                    .frame(width: columnLayout.width(for: column), alignment: alignment(for: column))
            }
            
            ignoreToggle
                .frame(width: FinderLayoutConstants.trailingAccessoryWidth, alignment: .center)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minHeight: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selectionBackground)
        )
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hoverBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(focusBorderColor, lineWidth: isFocused ? 1 : 0)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .highPriorityGesture(
            TapGesture().onEnded {
                onFocus()
            }
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
    }
    
    // MARK: - Columns
    
    @ViewBuilder
    private func columnView(for column: FinderColumn) -> some View {
        switch column {
        case .name:
            HStack(spacing: 8) {
                selectionButton
                FileThumbnailView(url: item.url)
                    .frame(width: 32, height: 32)
                Text(item.name)
                    .font(.system(size: 14))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
            }
        case .date:
            Text(formattedDate)
                .font(.system(size: 13))
                .foregroundStyle(metadataColor)
                .lineLimit(1)
        case .size:
            Text(item.formattedFileSize)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(metadataColor)
                .lineLimit(1)
        case .type:
            Text(typeLabel)
                .font(.system(size: 13))
                .foregroundStyle(metadataColor)
                .lineLimit(1)
        }
    }
    
    private var typeLabel: String {
        let ext = item.fileExtension
        if ext.isEmpty {
            return "Fichier"
        }
        return ext.uppercased()
    }
    
    private func alignment(for column: FinderColumn) -> Alignment {
        switch column {
        case .size:
            return .trailing
        default:
            return .leading
        }
    }
    
    // MARK: - Controls
    
    private var selectionButton: some View {
        Button {
            onToggleSelection()
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
        }
        .buttonStyle(.borderless)
        .help(isSelected ? "Retirer de la sélection" : "Sélectionner")
    }
    
    private var ignoreToggle: some View {
        Button(action: onToggleIgnored) {
            Image(systemName: isIgnored ? "star.fill" : "star")
                .foregroundStyle(isSelected ? Color.white : (isIgnored ? Color.yellow : Color.secondary))
        }
        .buttonStyle(.plain)
        .help(isIgnored ? "Autoriser à nouveau le rangement" : "Ne jamais proposer de ranger ce fichier")
    }
}
