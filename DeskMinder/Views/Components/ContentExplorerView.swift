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
                .padding(.vertical, 12)
            
            Divider()
            
            if selectedTab == .toClean && !scanner.items.isEmpty {
                selectionToolbar
                Divider()
            }
            
            currentContent
                .padding(12)
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(radius: 3, y: 2)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            statusBar
        }
    }
    
    // MARK: - Header & Toolbar
    
    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(ContentView.ListTab.allCases) { tab in
                Text(tabLabel(for: tab)).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .font(.headline)
        .padding(.horizontal)
    }
    
    private var selectionToolbar: some View {
        HStack() {
            
            if scanner.selectedCount > 0 {
                Text("\(scanner.selectedCount) selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    showingFolderPicker = true
                } label: {
                    Label("Move to...", systemImage: "folder")
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showingFolderPicker) {
                    FolderPickerView(scanner: scanner,
                                     showingNewFolderSheet: $showingNewFolderSheet)
                }
                
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Move to Bin", systemImage: "trash")
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
        if currentItems.isEmpty {
            emptyState(text: emptyStateText)
        } else {
            tableView
        }
    }
    
    private func tabLabel(for tab: ContentView.ListTab) -> String {
        switch tab {
        case .toClean:
            return "To Clean (\(scanner.items.count))"
        case .ignored:
            return "Ignored (\(scanner.ignoredItems.count))"
        }
    }
    
    private var currentItems: [DesktopItem] {
        switch selectedTab {
        case .toClean:
            return scanner.items
        case .ignored:
            return scanner.ignoredItems
        }
    }
    
    private var statusBar: some View {
        HStack {
            Text(statusBarText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
    
    @ViewBuilder
    private var tableView: some View {
        Table(of: DesktopItem.self,
              selection: $scanner.selectedItems,
              sortOrder: $scanner.sortOrder) {
            TableColumn("Name", value: \DesktopItem.displayName) { item in
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
            
            TableColumn("Date Modified", value: \DesktopItem.lastModified) { item in
                Text(item.formattedLastModified)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            TableColumn("Size", value: \DesktopItem.fileSize) { item in
                Text(item.formattedFileSize)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            TableColumn("Type", value: \DesktopItem.fileExtension) { item in
                Text(item.fileExtension)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } rows: {
            ForEach(currentItems) { item in
                TableRow(item)
                    .contextMenu {
                        tableRowContextMenu(for: item)
                    }
            }
        }
        .onChange(of: scanner.sortOrder) { _ in
            scanner.applySortOrder()
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func revealInFinder(_ item: DesktopItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    
    @ViewBuilder
    private func tableRowContextMenu(for item: DesktopItem) -> some View {
        Button("Reveal in Finder") {
            revealInFinder(item)
        }
        
        Divider()
        
        Button(isShowingIgnoredList ? "Allow cleanup suggestions again" : "Never suggest cleaning this file") {
            scanner.toggleIgnored(item)
        }
        
        if !isShowingIgnoredList {
            Divider()
            Button(scanner.selectedItems.contains(item.id) ? "Deselect" : "Select") {
                scanner.toggleSelection(item.id)
            }
        }
    }
    
    private var isShowingIgnoredList: Bool {
        selectedTab == .ignored
    }
    
    private var emptyStateText: String {
        isShowingIgnoredList ? "No ignored files." : "Nothing to clean 🎉"
    }
    
    private var statusBarText: String {
        let items = currentItems
        let total = items.count
        let fileWord = total == 1 ? "file" : "files"
        
        let base: String
        switch selectedTab {
        case .toClean:
            base = "\(total) \(fileWord) to review"
        case .ignored:
            base = "\(total) \(fileWord) ignored"
        }
        
        let selectedItems = items.filter { scanner.selectedItems.contains($0.id) }
        let selectionCount = selectedItems.count
        var components = [base, "\(selectionCount) selected"]
        
        if selectionCount > 0, let sizeText = selectedItemsSizeDescription(for: selectedItems) {
            components.append("Selected size: \(sizeText)")
        }
        
        return components.joined(separator: " — ")
    }
    
    private func selectedItemsSizeDescription(for selectedItems: [DesktopItem]) -> String? {
        let totalBytes = selectedItems.reduce(Int64(0)) { partial, item in
            partial + item.fileSize
        }
        guard totalBytes > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
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
