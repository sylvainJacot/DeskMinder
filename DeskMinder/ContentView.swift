import SwiftUI
import AppKit
import Quartz
import QuickLookThumbnailing

struct ContentView: View {
    @ObservedObject var scanner: DesktopScanner
    @State private var showingDeleteConfirmation = false
    @State private var showingFolderPicker = false
    @State private var showingNewFolderSheet = false
    @State private var spaceKeyMonitor: Any?
    @State private var focusedItemID: UUID?
    private let quickLookCoordinator = QuickLookPreviewCoordinator()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            
            if let score = scanner.cleanlinessScore {
                cleanlinessCard(for: score)
            }
            
            Divider()
            
            if !scanner.items.isEmpty {
                selectionToolbar
                Divider()
            }
            
            List {
                ForEach(scanner.items) { item in
                    DesktopItemRow(
                        item: item,
                        isSelected: scanner.selectedItems.contains(item.id),
                        onToggleSelection: {
                            scanner.toggleSelection(item.id)
                        },
                        onFocus: {
                            focusedItemID = item.id
                        },
                        isFocused: focusedItemID == item.id
                    )
                }
            }
            
            if scanner.items.isEmpty {
                emptyState
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .alert("Confirmer la suppression", isPresented: $showingDeleteConfirmation) {
            Button("Annuler", role: .cancel) { }
            Button("Mettre à la corbeille", role: .destructive) {
                handleMoveToTrash()
            }
        } message: {
            Text("Voulez-vous déplacer \(scanner.selectedCount) fichier(s) vers la corbeille ?")
        }
        .sheet(isPresented: $showingNewFolderSheet) {
            NewFolderSheet(scanner: scanner)
        }
        .onAppear {
            installSpaceKeyMonitor()
        }
        .onDisappear {
            removeSpaceKeyMonitor()
        }
        .onChange(of: scanner.selectedItems) { _ in
            refreshQuickLookSelection()
        }
        .onChange(of: focusedItemID) { _ in
            refreshQuickLookSelection()
        }
    }

    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DeskMinder")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    scanner.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Rafraîchir la liste")
            }
            
            if !scanner.items.isEmpty {
                Text("\(scanner.items.count) fichier(s) à ranger")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Seuil : \(scanner.minDaysOld) jours")
                    .font(.subheadline)
                
                Spacer()
                
                Picker("Tri", selection: $scanner.sortOption) {
                    ForEach(DesktopScanner.SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
            }
            
            Slider(
                value: Binding(
                    get: { Double(scanner.minDaysOld) },
                    set: { newValue in
                        let roundedValue = Int(newValue.rounded())
                        let clampedValue = min(
                            max(roundedValue, DesktopScanner.allowedDaysRange.lowerBound),
                            DesktopScanner.allowedDaysRange.upperBound
                        )
                        scanner.minDaysOld = clampedValue
                    }
                ),
                in: Double(DesktopScanner.allowedDaysRange.lowerBound)...Double(DesktopScanner.allowedDaysRange.upperBound),
                step: 1
            )
        }
        .padding()
    }

    // MARK: - Cleanliness Score
    
    @ViewBuilder
    private func cleanlinessCard(for score: DeskCleanlinessScore) -> some View {
        let accentColor = cleanlinessAccentColor(for: score.score)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("Indice de propreté du bureau :")
                    .font(.headline)
                Text("\(score.score)/100")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)
            }
            
            ProgressView(value: Double(score.score), total: 100)
                .tint(accentColor)
            
            HStack {
                Text(fileCountLabel(score.fileCount))
                Spacer()
                Text(oldFileCountLabel(score.oldFileCount))
                Spacer()
                Text("Âge moyen : \(score.formattedAverageAge) jours")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .padding()
    }
    
    private func cleanlinessAccentColor(for score: Int) -> Color {
        switch score {
        case 80...100:
            return .green
        case 50..<80:
            return .orange
        default:
            return .red
        }
    }
    
    private func fileCountLabel(_ count: Int) -> String {
        count > 1 ? "\(count) fichiers" : "\(count) fichier"
    }
    
    private func oldFileCountLabel(_ count: Int) -> String {
        count > 1 ? "\(count) fichiers anciens" : "\(count) fichier ancien"
    }
    
    // MARK: - Selection Toolbar
    
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
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("Aucun fichier à ranger 🎉")
                .font(.headline)
            
            Text("Votre bureau est bien organisé !")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Actions
    
    private func handleMoveToTrash() {
        let result = scanner.moveSelectedToTrash()
        
        switch result {
        case .success(let count):
            print("✅ \(count) fichier(s) déplacé(s) vers la corbeille")
        case .failure(let error):
            print("❌ Erreur : \(error.localizedDescription)")
            // TODO: Afficher une alerte d'erreur
        }
    }
    
    private func previewSelectedItems() {
        let selectedURLs = currentSelectionURLs()
        
        guard !selectedURLs.isEmpty else {
            closeQuickLookPanel()
            return
        }
        
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.orderOut(nil)
        } else {
            showQuickLookPanel(with: selectedURLs)
        }
    }
    
    private func currentSelectionURLs() -> [URL] {
        if let focusedId = focusedItemID,
           let focusedItem = scanner.items.first(where: { $0.id == focusedId }) {
            return [focusedItem.url]
        }
        
        let selected = scanner.items.filter { scanner.selectedItems.contains($0.id) }
        if !selected.isEmpty {
            return selected.map { $0.url }
        }
        
        return []
    }
    
    private func showQuickLookPanel(with urls: [URL]) {
        quickLookCoordinator.updateItems(urls)
        
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = quickLookCoordinator
        panel.delegate = quickLookCoordinator
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }
    
    private func refreshQuickLookSelection() {
        guard let panel = QLPreviewPanel.shared(),
              panel.isVisible else { return }
        
        let selectedURLs = currentSelectionURLs()
        
        if selectedURLs.isEmpty {
            panel.orderOut(nil)
            return
        }
        
        quickLookCoordinator.updateItems(selectedURLs)
        panel.reloadData()
        panel.refreshCurrentPreviewItem()
    }
    
    private func closeQuickLookPanel() {
        guard let panel = QLPreviewPanel.shared(),
              panel.isVisible else { return }
        panel.orderOut(nil)
    }
    
    private func installSpaceKeyMonitor() {
        guard spaceKeyMonitor == nil else { return }
        spaceKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event)
        }
    }
    
    private func removeSpaceKeyMonitor() {
        if let monitor = spaceKeyMonitor {
            NSEvent.removeMonitor(monitor)
            spaceKeyMonitor = nil
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard event.keyCode == 49 else {
            return event
        }
        
        if let responder = event.window?.firstResponder,
           responder is NSTextView {
            return event
        }
        
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            previewSelectedItems()
            return nil
        }
        
        return event
    }
}

// MARK: - Desktop Item Rowd

struct DesktopItemRow: View {
    let item: DesktopItem
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onFocus: () -> Void
    let isFocused: Bool
    
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
            
            VStack(alignment: .trailing) {
                Text("\(item.daysOld) j")
                    .font(.headline)
                    .foregroundColor(item.daysOld > 30 ? .red : .primary)
                
                Text("sur le bureau")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
            
            Button("Sélectionner") {
                onToggleSelection()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Folder Picker

struct FolderPickerView: View {
    @ObservedObject var scanner: DesktopScanner
    @Binding var showingNewFolderSheet: Bool 
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedFolder: URL?
    
    private let commonFolders: [(name: String, url: URL?)] = {
        let fm = FileManager.default
        return [
            ("Documents", fm.urls(for: .documentDirectory, in: .userDomainMask).first),
            ("Images", fm.urls(for: .picturesDirectory, in: .userDomainMask).first),
            ("Téléchargements", fm.urls(for: .downloadsDirectory, in: .userDomainMask).first)
        ]
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Déplacer vers un dossier")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Dossiers rapides")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(commonFolders, id: \.name) { folder in
                    if let url = folder.url {
                        Button {
                            moveToFolder(url)
                        } label: {
                            HStack {
                                Image(systemName: iconForFolder(folder.name))
                                Text(folder.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
            }
            
            Divider()
            
            Button {
                selectCustomFolder()
            } label: {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Choisir un autre dossier…")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
        Button {
            dismiss()
            showingNewFolderSheet = true       // 👈 tout simple
        } label: {
            HStack {
                Image(systemName: "folder.badge.plus")
                Text("Créer un nouveau dossier…")
                Spacer()
            }
        }
        .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 280)
    }
    
    private func iconForFolder(_ name: String) -> String {
        switch name {
        case "Documents": return "doc.fill"
        case "Images": return "photo.fill"
        case "Téléchargements": return "arrow.down.circle.fill"
        default: return "folder.fill"
        }
    }
    
    private func moveToFolder(_ url: URL) {
        let result = scanner.moveSelectedToFolder(url)
        
        switch result {
        case .success(let count):
            print("✅ \(count) fichier(s) déplacé(s)")
            dismiss()
        case .failure(let error):
            print("❌ Erreur : \(error.localizedDescription)")
        }
    }
    
    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choisissez un dossier de destination"
        
        if panel.runModal() == .OK, let url = panel.url {
            moveToFolder(url)
        }
    }
}

// MARK: - New Folder Sheet

struct NewFolderSheet: View {
    @ObservedObject var scanner: DesktopScanner
    @Environment(\.dismiss) var dismiss
    
    @State private var folderName: String = ""
    @State private var selectedLocation: FolderLocation = .desktop
    
    enum FolderLocation: String, CaseIterable {
        case desktop = "Bureau"
        case documents = "Documents"
        
        var url: URL? {
            let fm = FileManager.default
            switch self {
            case .desktop:
                return fm.urls(for: .desktopDirectory, in: .userDomainMask).first
            case .documents:
                return fm.urls(for: .documentDirectory, in: .userDomainMask).first
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Créer un nouveau dossier")
                .font(.headline)
            
            TextField("Nom du dossier", text: $folderName)
                .textFieldStyle(.roundedBorder)
            
            Picker("Emplacement", selection: $selectedLocation) {
                ForEach(FolderLocation.allCases, id: \.self) { location in
                    Text(location.rawValue).tag(location)
                }
            }
            .pickerStyle(.segmented)
            
            HStack {
                Button("Annuler") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Créer et déplacer") {
                    createFolderAndMove()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(folderName.isEmpty)
            }
        }
        .padding()
        .frame(width: 320)
    }
    
    private func createFolderAndMove() {
        guard let parentURL = selectedLocation.url else { return }
        
        let result = scanner.createFolderAndMove(folderName: folderName, in: parentURL)
        
        switch result {
        case .success(let folderURL):
            print("✅ Dossier créé et fichiers déplacés vers : \(folderURL.path)")
            dismiss()
        case .failure(let error):
            print("❌ Erreur : \(error.localizedDescription)")
        }
    }
}

#if DEBUG
final class DesktopScannerPreviewMock: DesktopScanner {
    private let previewScore: DeskCleanlinessScore
    
    init(score: DeskCleanlinessScore) {
        self.previewScore = score
        super.init()
        self.cleanlinessScore = score
    }
    
    override func refresh() {
        cleanlinessScore = previewScore
    }
}

#Preview("Score élevé") {
    ContentView(scanner: DesktopScannerPreviewMock(score: DeskCleanlinessScore(fileCount: 5, oldFileCount: 1, averageAge: 2)))
}

#Preview("Score moyen") {
    ContentView(scanner: DesktopScannerPreviewMock(score: DeskCleanlinessScore(fileCount: 20, oldFileCount: 8, averageAge: 12)))
}

#Preview("Score faible") {
    ContentView(scanner: DesktopScannerPreviewMock(score: DeskCleanlinessScore(fileCount: 45, oldFileCount: 25, averageAge: 45)))
}
#endif

// MARK: - Quick Look Coordinator

final class QuickLookPreviewCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var items: [URL] = []
    
    func updateItems(_ urls: [URL]) {
        items = urls
    }
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        items.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem {
        items[index] as NSURL
    }
}

// MARK: - File Thumbnail View

struct FileThumbnailView: View {
    let url: URL
    private let size: CGFloat = 32
    
    @State private var thumbnail: NSImage?
    @State private var isGenerating = false
    
    var body: some View {
        Image(nsImage: thumbnail ?? fallbackIcon)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .cornerRadius(4)
            .onAppear(perform: generateThumbnailIfNeeded)
            .onChange(of: url) { _ in
                thumbnail = nil
                generateThumbnailIfNeeded()
            }
    }
    
    private var fallbackIcon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
    
    private func generateThumbnailIfNeeded() {
        guard thumbnail == nil, !isGenerating else { return }
        isGenerating = true
        
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size, height: size),
            scale: scale,
            representationTypes: .all
        )
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
            DispatchQueue.main.async {
                self.isGenerating = false
                if let image = representation?.nsImage {
                    self.thumbnail = image
                }
            }
        }
    }
}
