import SwiftUI

struct ContentExplorerView: View {
    @ObservedObject var scanner: DesktopScanner
    @Binding var selectedTab: ContentView.ListTab
    @Binding var focusedItemID: UUID?
    @Binding var showingFolderPicker: Bool
    @Binding var showingNewFolderSheet: Bool
    @Binding var showingDeleteConfirmation: Bool
    var focusItem: (UUID) -> Void
    
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    switch selectedTab {
                    case .toClean:
                        toCleanList
                    case .ignored:
                        ignoredList
                    }
                }
                .padding([.horizontal, .bottom])
            }
        }
    }
    
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
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var toCleanList: some View {
        Group {
            if scanner.items.isEmpty {
                Text("Aucun fichier à ranger 🎉")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            } else {
                ForEach(scanner.items) { item in
                    DesktopItemRow(
                        item: item,
                        isSelected: scanner.selectedItems.contains(item.id),
                        onToggleSelection: {
                            scanner.toggleSelection(item.id)
                        },
                        onFocus: {
                            focusItem(item.id)
                        },
                        isFocused: focusedItemID == item.id,
                        isIgnored: scanner.isIgnored(item),
                        onToggleIgnored: {
                            scanner.toggleIgnored(item)
                        }
                    )
                }
            }
        }
    }
    
    private var ignoredList: some View {
        Group {
            if scanner.ignoredItems.isEmpty {
                Text("Aucun fichier ignoré.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            } else {
                ForEach(scanner.ignoredItems) { item in
                    DesktopItemRow(
                        item: item,
                        isSelected: false,
                        onToggleSelection: { },
                        onFocus: {
                            focusItem(item.id)
                        },
                        isFocused: focusedItemID == item.id,
                        isIgnored: true,
                        onToggleIgnored: {
                            scanner.toggleIgnored(item)
                        }
                    )
                }
            }
        }
    }
}
