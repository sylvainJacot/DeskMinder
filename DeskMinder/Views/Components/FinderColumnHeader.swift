import SwiftUI
import UniformTypeIdentifiers

struct FinderColumnHeader: View {
    @Binding var sortOption: DesktopScanner.SortOption
    @Binding var columnLayout: FinderColumnLayout
    @Binding var columnOrder: [FinderColumn]
    
    @State private var draggingColumn: FinderColumn?
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(columnOrder.enumerated()), id: \.element) { index, column in
                columnButton(for: column)
                    .frame(width: columnLayout.width(for: column), alignment: alignment(for: column))
                    .onDrag {
                        draggingColumn = column
                        return NSItemProvider(object: column.rawValue as NSString)
                    }
                    .onDrop(
                        of: [UTType.plainText],
                        delegate: FinderColumnDropDelegate(
                            targetColumn: column,
                            columnOrder: $columnOrder,
                            draggingColumn: $draggingColumn
                        )
                    )
                
                if index < columnOrder.count - 1 {
                    FinderColumnResizeHandle(column: column, columnLayout: $columnLayout)
                }
            }
            
            Color.clear
                .frame(width: FinderLayoutConstants.trailingAccessoryWidth)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }
    
    // MARK: - Helpers
    
    private func columnButton(for column: FinderColumn) -> some View {
        let options = sortOptions(for: column)
        return Button {
            toggleSort(ascending: options.ascending, descending: options.descending)
        } label: {
            HStack(spacing: 4) {
                Text(title(for: column))
                if let indicator = sortIndicator(for: column) {
                    indicator
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment(for: column))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func title(for column: FinderColumn) -> String {
        switch column {
        case .name: return "Nom"
        case .date: return "Date"
        case .size: return "Taille"
        case .type: return "Type"
        }
    }
    
    private func alignment(for column: FinderColumn) -> Alignment {
        switch column {
        case .size:
            return .trailing
        default:
            return .leading
        }
    }
    
    private func sortOptions(for column: FinderColumn) -> (ascending: DesktopScanner.SortOption, descending: DesktopScanner.SortOption) {
        switch column {
        case .name:
            return (.nameAsc, .nameDesc)
        case .date:
            return (.dateOldest, .dateNewest)
        case .size:
            return (.sizeAsc, .sizeDesc)
        case .type:
            return (.typeAsc, .typeDesc)
        }
    }
    
    private func toggleSort(
        ascending: DesktopScanner.SortOption,
        descending: DesktopScanner.SortOption
    ) {
        sortOption = (sortOption == ascending) ? descending : ascending
    }
    
    private func sortIndicator(for column: FinderColumn) -> Image? {
        let options = sortOptions(for: column)
        switch sortOption {
        case options.ascending:
            return Image(systemName: "chevron.up")
        case options.descending:
            return Image(systemName: "chevron.down")
        default:
            return nil
        }
    }
}

// MARK: - Resize Handle & Drop Delegate

private struct FinderColumnResizeHandle: View {
    let column: FinderColumn
    @Binding var columnLayout: FinderColumnLayout
    @State private var initialWidth: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6, height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            initialWidth = columnLayout.width(for: column)
                            isDragging = true
                        }
                        let newWidth = initialWidth + value.translation.width
                        columnLayout = columnLayout.settingWidth(newWidth, for: column)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1)
            )
    }
}

private struct FinderColumnDropDelegate: DropDelegate {
    let targetColumn: FinderColumn
    @Binding var columnOrder: [FinderColumn]
    @Binding var draggingColumn: FinderColumn?
    
    func dropEntered(info: DropInfo) {
        guard let dragging = draggingColumn,
              dragging != targetColumn else { return }
        moveColumn(dragging, to: targetColumn)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingColumn = nil
        return true
    }
    
    func dropExited(info: DropInfo) {
        draggingColumn = nil
    }
    
    private func moveColumn(_ dragged: FinderColumn, to target: FinderColumn) {
        guard let fromIndex = columnOrder.firstIndex(of: dragged) else { return }
        var newOrder = columnOrder
        newOrder.remove(at: fromIndex)
        if let updatedTargetIndex = newOrder.firstIndex(of: target) {
            newOrder.insert(dragged, at: updatedTargetIndex)
        } else {
            newOrder.append(dragged)
        }
        columnOrder = newOrder
    }
}
