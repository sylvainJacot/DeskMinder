import SwiftUI
import AppKit

struct ContentExplorerView: View {
    @ObservedObject var scanner: DesktopScanner
    @Binding var selectedTab: ContentView.ListTab
    @Binding var focusedItemID: UUID?
    @Binding var showingFolderPicker: Bool
    @Binding var showingNewFolderSheet: Bool
    @Binding var showingDeleteConfirmation: Bool
    var focusItem: (UUID) -> Void
    
    @State private var columnLayout = FinderColumnLayout()
    @State private var columnOrder: [FinderColumn] = Array(FinderColumn.allCases)
    
    init(
        scanner: DesktopScanner,
        selectedTab: Binding<ContentView.ListTab>,
        focusedItemID: Binding<UUID?>,
        showingFolderPicker: Binding<Bool>,
        showingNewFolderSheet: Binding<Bool>,
        showingDeleteConfirmation: Binding<Bool>,
        focusItem: @escaping (UUID) -> Void
    ) {
        self._scanner = ObservedObject(wrappedValue: scanner)
        self._selectedTab = selectedTab
        self._focusedItemID = focusedItemID
        self._showingFolderPicker = showingFolderPicker
        self._showingNewFolderSheet = showingNewFolderSheet
        self._showingDeleteConfirmation = showingDeleteConfirmation
        self.focusItem = focusItem
        let preferences = FinderColumnPreferences.load()
        self._columnLayout = State(initialValue: preferences.layout)
        self._columnOrder = State(initialValue: preferences.order)
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
                
                VStack(spacing: 0) {
                    listHeader
                    ScrollView {
                        VStack(spacing: 0) {
                            switch selectedTab {
                            case .toClean:
                                toCleanList
                            case .ignored:
                                ignoredList
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.visible)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .environment(\.finderColumnLayout, columnLayout)
        .environment(\.finderColumnOrder, columnOrder)
        .onChange(of: columnLayout) { _ in
            saveColumnPreferences()
        }
        .onChange(of: columnOrder) { _ in
            saveColumnPreferences()
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
    
    // MARK: - Lists
    
    private var listHeader: some View {
        Group {
            if currentItems.isEmpty {
                EmptyView()
            } else {
                FinderColumnHeader(sortOption: $scanner.sortOption,
                                   columnLayout: $columnLayout,
                                   columnOrder: $columnOrder)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
        }
    }
    
    private var currentItems: [DesktopItem] {
        selectedTab == .ignored ? scanner.ignoredItems : scanner.items
    }
    
    private var toCleanList: some View {
        Group {
            if scanner.items.isEmpty {
                emptyState(text: "Aucun fichier à ranger 🎉")
            } else {
                finderRows(for: scanner.items, allowSelection: true)
            }
        }
    }
    
    private var ignoredList: some View {
        Group {
            if scanner.ignoredItems.isEmpty {
                emptyState(text: "Aucun fichier ignoré.")
            } else {
                finderRows(for: scanner.ignoredItems, allowSelection: false)
            }
        }
    }

    private func finderRows(for items: [DesktopItem], allowSelection: Bool) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                DesktopItemRow(
                    item: item,
                    isSelected: allowSelection ? scanner.selectedItems.contains(item.id) : false,
                    onToggleSelection: {
                        guard allowSelection else { return }
                        scanner.toggleSelection(item.id)
                    },
                    onFocus: {
                        focusItem(item.id)
                    },
                    isFocused: focusedItemID == item.id,
                    isIgnored: allowSelection ? scanner.isIgnored(item) : true,
                    onToggleIgnored: {
                        scanner.toggleIgnored(item)
                    }
                )
                
                if index < items.count - 1 {
                    FinderDivider()
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
    
    // MARK: - Helpers
    
    private func emptyState(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }
    
    private func saveColumnPreferences() {
        FinderColumnPreferences(layout: columnLayout, order: columnOrder).save()
    }
}

private struct FinderDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.35))
            .frame(height: 0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
    }
}
