import SwiftUI

struct FinderColumnHeader: View {
    @Binding var sortOption: DesktopScanner.SortOption
    @Binding var columnLayout: FinderColumnLayout
    
    var body: some View {
        HStack(spacing: 0) {
            columnButton(
                title: "Nom",
                column: .name,
                alignment: .leading,
                ascending: .nameAsc,
                descending: .nameDesc
            )
            resizeHandle(for: .name)
            
            columnButton(
                title: "Date",
                column: .date,
                alignment: .leading,
                ascending: .dateOldest,
                descending: .dateNewest
            )
            resizeHandle(for: .date)
            
            columnButton(
                title: "Taille",
                column: .size,
                alignment: .trailing,
                ascending: .sizeAsc,
                descending: .sizeDesc
            )
            resizeHandle(for: .size)
            
            columnButton(
                title: "Type",
                column: .type,
                alignment: .leading,
                ascending: .typeAsc,
                descending: .typeDesc
            )
            
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
    
    private func columnButton(
        title: String,
        column: FinderColumn,
        alignment: Alignment,
        ascending: DesktopScanner.SortOption,
        descending: DesktopScanner.SortOption
    ) -> some View {
        Button {
            toggleSort(ascending: ascending, descending: descending)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if let indicator = sortIndicator(for: ascending, descending: descending) {
                    indicator
                }
            }
            .frame(width: columnLayout.width(for: column), alignment: alignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func resizeHandle(for column: FinderColumn) -> some View {
        FinderColumnResizeHandle(column: column, columnLayout: $columnLayout)
    }
    
    private func toggleSort(
        ascending: DesktopScanner.SortOption,
        descending: DesktopScanner.SortOption
    ) {
        if sortOption == ascending {
            sortOption = descending
        } else {
            sortOption = ascending
        }
    }
    
    private func sortIndicator(
        for ascending: DesktopScanner.SortOption,
        descending: DesktopScanner.SortOption
    ) -> Image? {
        switch sortOption {
        case ascending:
            return Image(systemName: "chevron.up")
        case descending:
            return Image(systemName: "chevron.down")
        default:
            return nil
        }
    }
}

// MARK: - Resize Handle

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
