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
            
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.08), radius: 1, y: 1)
                
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
        HStack() {
            
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
        if currentItems.isEmpty {
            emptyState(text: emptyStateText)
        } else {
            tableView
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
    
    @ViewBuilder
    private var tableView: some View {
        Table(of: DesktopItem.self,
              selection: $scanner.selectedItems,
              sortOrder: $scanner.sortOrder) {
            TableColumn("Nom", value: \DesktopItem.displayName) { item in
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
            
            TableColumn("Date modifiée", value: \DesktopItem.lastModified) { item in
                Text(item.formattedLastModified)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            TableColumn("Taille", value: \DesktopItem.fileSize) { item in
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
        Button("Afficher dans le Finder") {
            revealInFinder(item)
        }
        
        Divider()
        
        Button(isShowingIgnoredList ? "Autoriser à nouveau le rangement" : "Ne jamais proposer de ranger ce fichier") {
            scanner.toggleIgnored(item)
        }
        
        if !isShowingIgnoredList {
            Divider()
            Button(scanner.selectedItems.contains(item.id) ? "Désélectionner" : "Sélectionner") {
                scanner.toggleSelection(item.id)
            }
        }
    }
    
    private var isShowingIgnoredList: Bool {
        selectedTab == .ignored
    }
    
    private var emptyStateText: String {
        isShowingIgnoredList ? "Aucun fichier ignoré." : "Aucun fichier à ranger 🎉"
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
