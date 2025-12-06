import SwiftUI
import AppKit

struct ContentExplorerView: View {
    @ObservedObject var scanner: DesktopScanner
    @Binding var selectedTab: ContentView.ListTab
    @Binding var focusedItemID: UUID?
    @Binding var showingFolderPicker: Bool
    @Binding var showingNewFolderSheet: Bool
    @Binding var showingDeleteConfirmation: Bool
    
    
    init(
        scanner: DesktopScanner,
        selectedTab: Binding<ContentView.ListTab>,
        focusedItemID: Binding<UUID?>,
        showingFolderPicker: Binding<Bool>,
        showingNewFolderSheet: Binding<Bool>,
        showingDeleteConfirmation: Binding<Bool>
    ) {
        self._scanner = ObservedObject(wrappedValue: scanner)
        self._selectedTab = selectedTab
        self._focusedItemID = focusedItemID
        self._showingFolderPicker = showingFolderPicker
        self._showingNewFolderSheet = showingNewFolderSheet
        self._showingDeleteConfirmation = showingDeleteConfirmation
    }
    
    var body: some View {
        VStack(spacing: 0) {
            tabPicker
                .padding(.horizontal)
                .padding(.bottom, 12)
            
            Divider()
            
            if selectedTab == .toClean && !scanner.items.isEmpty {
                selectionToolbar
                Divider()
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                currentContent
                    .padding(12)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Header & Toolbar
    
    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(ContentView.ListTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            Button {
                if scanner.isAllSelected {
                    scanner.deselectAll()
                } else {
                    scanner.selectAll()
                }
            } label: {
                Image(systemName: scanner.isAllSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(scanner.isAllSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help(scanner.isAllSelected ? "Tout désélectionner" : "Tout sélectionner")
            
            if scanner.selectedCount > 0 {
                Text("\(scanner.selectedCount) sélectionné(s)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    showingFolderPicker = true
                } label: {
                    Label("Déplacer vers…", systemImage: "folder")
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showingFolderPicker) {
                    FolderPickerView(scanner: scanner,
                                     showingNewFolderSheet: $showingNewFolderSheet)
                }
                
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Corbeille", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [
                Color(nsColor: .controlBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(0.6)
            ], startPoint: .top, endPoint: .bottom)
        )
    }
    
    // MARK: - Table Content
    
    @ViewBuilder
    private var currentContent: some View {
        switch selectedTab {
        case .toClean:
            if scanner.items.isEmpty {
                emptyState(text: "Aucun fichier à ranger 🎉")
            } else {
                tableView(for: scanner.items, isIgnoredList: false)
            }
        case .ignored:
            if scanner.ignoredItems.isEmpty {
                emptyState(text: "Aucun fichier ignoré.")
            } else {
                tableView(for: scanner.ignoredItems, isIgnoredList: true)
            }
        }
    }
    
    private func tableView(for items: [DesktopItem], isIgnoredList: Bool) -> some View {
        Table(
            items,
            selection: selectionBinding(for: isIgnoredList),
            sortOrder: $scanner.sortOrder
        ) {
            TableColumn("Nom", value: \.displayName) { item in
                HStack(spacing: 8) {
                    FileThumbnailView(url: item.url)
                        .frame(width: 32, height: 32)
                    Text(item.displayName)
                        .font(.callout)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            
            TableColumn("Date", value: \.modificationDate) { item in
                Text(item.formattedModificationDate)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            TableColumn("Taille", value: \.fileSize) { item in
                Text(item.formattedFileSize)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            TableColumn("Type", value: \.fileExtension) { item in
                Text(item.fileExtension)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contextMenu(forSelectionType: DesktopItem.ID.self) { selection in
            rowContextMenu(forSelection: selection, isIgnoredList: isIgnoredList)
        }
    }
    
    private func selectionBinding(for isIgnoredList: Bool) -> Binding<Set<DesktopItem.ID>> {
        Binding(
            get: { scanner.selectedItems },
            set: { scanner.selectedItems = $0 }
        )
    }
    
    @ViewBuilder
    private func rowContextMenu(forSelection selection: Set<DesktopItem.ID>, isIgnoredList: Bool) -> some View {
        if let item = targetItem(from: selection, isIgnoredList: isIgnoredList) {
            Button("Afficher dans le Finder") {
                revealInFinder(item)
            }
            
            Divider()
            
            Button(isIgnoredList ? "Autoriser à nouveau le rangement" : "Ne jamais proposer de ranger ce fichier") {
                scanner.toggleIgnored(item)
            }
            
            if !isIgnoredList {
                Divider()
                Button(scanner.selectedItems.contains(item.id) ? "Désélectionner" : "Sélectionner") {
                    scanner.toggleSelection(item.id)
                }
            }
        } else {
            EmptyView()
        }
    }
    
    private func targetItem(from selection: Set<DesktopItem.ID>, isIgnoredList: Bool) -> DesktopItem? {
        let source = isIgnoredList ? scanner.ignoredItems : scanner.items
        if selection.isEmpty {
            return focusedItemID.flatMap { id in source.first { $0.id == id } }
        }
        return source.first { selection.contains($0.id) }
    }
    
    private func revealInFinder(_ item: DesktopItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    
    // MARK: - Helpers
    
    private func emptyState(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }
}
