import SwiftUI
import AppKit
import Quartz
import Combine

// MARK: - Updates Models & Logic

struct UpdateInfo: Decodable {
    let latest: String
    let minSupported: String?
    let notes: String?
    let download: String
}

final class UpdateChecker: ObservableObject {
    @Published var updateAvailable: Bool = false
    @Published var updateInfo: UpdateInfo?

    init() {}

    // Récupère la version actuelle (CFBundleShortVersionString)
    private func currentVersion() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    /// Compare deux versions de type "1.2.3"
    private func isNewer(_ remote: String, than local: String) -> Bool {
        func parts(_ v: String) -> [Int] {
            v.split(separator: ".").compactMap { Int($0) }
        }

        let a = parts(local)
        let b = parts(remote)

        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if y != x { return y > x }
        }
        return false
    }

    /// Lance une vérification d'update à partir d'une URL JSON
    func check(url: URL) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self,
                  error == nil,
                  let data = data,
                  let info = try? JSONDecoder().decode(UpdateInfo.self, from: data) else {
                return
            }

            let current = self.currentVersion()
            let newer = self.isNewer(info.latest, than: current)

            DispatchQueue.main.async {
                self.updateInfo = info
                self.updateAvailable = newer
            }
        }
        task.resume()
    }
}


// MARK: - Update Sheet View

struct UpdateSheetView: View {
    let info: UpdateInfo
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A new version is available")
                .font(.title2)
                .bold()

            Text("Current version: \(currentVersionString())")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("New version: \(info.latest)")
                .font(.headline)

            if let notes = info.notes, !notes.isEmpty {
                Text("Release notes:")
                    .font(.subheadline)
                    .bold()
                ScrollView {
                    Text(notes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(8)
                }
                .frame(minHeight: 120, maxHeight: 220)
            }

            HStack {
                Spacer()
                Button("Later") {
                    isPresented = false
                }
                Button("Download") {
                    if let url = URL(string: info.download) {
                        NSWorkspace.shared.open(url)
                    }
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func currentVersionString() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Unknown"
    }
}

// MARK: - Main Content View

struct ContentView: View {
    enum ListTab: String, CaseIterable, Identifiable {
        case toClean
        case ignored
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .toClean: return "To Clean"
            case .ignored: return "Ignored"
            }
        }
    }
    
    enum ThresholdUnit: String, CaseIterable, Identifiable {
        case days
        case months
        case years
        
        var id: String { rawValue }
        
        var label: String {
            switch self {
            case .days:   return "days"
            case .months: return "months"
            case .years:  return "years"
            }
        }
        
        func toDays(_ value: Int) -> Int {
            switch self {
            case .days:
                return value
            case .months:
                return value * 30   // approximation suffisante
            case .years:
                return value * 365  // approximation suffisante
            }
        }
        
        func formatted(_ value: Int) -> String {
            switch self {
            case .days:
                return value == 1 ? "1 day" : "\(value) days"
            case .months:
                return value == 1 ? "1 month" : "\(value) months"
            case .years:
                return value == 1 ? "1 year" : "\(value) years"
            }
        }
    }
    
    @ObservedObject var scanner: DesktopScanner

    // MARK: - Update state
    @StateObject private var updateChecker = UpdateChecker()
    @State private var showingUpdateSheet = false

    @State private var showingDeleteConfirmation = false
    @State private var showingFolderPicker = false
    @State private var showingNewFolderSheet = false
    @State private var spaceKeyMonitor: Any?
    @State private var focusedItemID: UUID?
    @State private var selectedTab: ListTab = .toClean
    @State private var thresholdValue: Double = 7
    @State private var thresholdUnit: ThresholdUnit = .days
    @AppStorage("autoCleanEnabled") private var autoCleanEnabled = false
    private let quickLookCoordinator = QuickLookPreviewCoordinator()
    
    var body: some View {
        NavigationSplitView {
            MainSidebarView(
                scanner: scanner,
                thresholdValue: $thresholdValue,
                thresholdUnit: $thresholdUnit,
                autoCleanEnabled: $autoCleanEnabled
            )
        } detail: {
            ContentExplorerView(
                scanner: scanner,
                selectedTab: $selectedTab,
                focusedItemID: $focusedItemID,
                showingFolderPicker: $showingFolderPicker,
                showingNewFolderSheet: $showingNewFolderSheet,
                showingDeleteConfirmation: $showingDeleteConfirmation
            )
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        .transaction { transaction in
            transaction.animation = nil
        }
        .frame(minWidth: 800, maxWidth: 1000, minHeight: 760, maxHeight: 820)
        .alert("Confirm deletion", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Bin", role: .destructive) {
                handleMoveToTrash()
            }
        } message: {
            Text("Move \(scanner.selectedCount) selected file(s) to the Trash?")
        }
        .sheet(isPresented: $showingNewFolderSheet) {
            NewFolderSheet(scanner: scanner)
        }
        // Sheet de mise à jour
        .sheet(isPresented: $showingUpdateSheet) {
            if let info = updateChecker.updateInfo {
                UpdateSheetView(info: info, isPresented: $showingUpdateSheet)
            }
        }
        .onAppear {
            syncFromScanner()
            installSpaceKeyMonitor()

            // ⚠️ Remplace cette URL par celle de ton appcast JSON (hébergé sur GitHub Pages, par exemple)
            if let url = URL(string: "https://sylvainjacot.github.io/DeskMinder/appcast.json") {
                updateChecker.check(url: url)
            }
        }
        .onDisappear {
            removeSpaceKeyMonitor()
        }
        .onChange(of: scanner.selectedItems) { newSelection in
            updateFocusedItem(from: newSelection)
            refreshQuickLookSelection()
        }
        .onChange(of: focusedItemID) { _ in
            refreshQuickLookSelection()
        }
        .onChange(of: thresholdValue) { _ in
            applyThresholdChange()
        }
        .onChange(of: thresholdUnit) { _ in
            applyThresholdChange()
        }
        // Quand une update est détectée, on affiche la sheet
        .onChange(of: updateChecker.updateAvailable) { newValue in
            if newValue {
                showingUpdateSheet = true
            }
        }
    }
    
    // MARK: - Threshold Helpers
    
    private func syncFromScanner() {
        let days = scanner.minDaysOld
        
        if days % 365 == 0 && days >= 365 {
            thresholdUnit = .years
            thresholdValue = Double(max(days / 365, 1))
        } else if days % 30 == 0 && days >= 30 {
            thresholdUnit = .months
            thresholdValue = Double(max(days / 30, 1))
        } else {
            thresholdUnit = .days
            thresholdValue = Double(max(days, 1))
        }
    }
    
    private func applyThresholdChange() {
        let roundedValue = Int(thresholdValue.rounded())
        let rawDays = thresholdUnit.toDays(roundedValue)
        let clampedDays = min(
            max(rawDays, DesktopScanner.allowedDaysRange.lowerBound),
            DesktopScanner.allowedDaysRange.upperBound
        )
        scanner.minDaysOld = clampedDays
        thresholdValue = Double(roundedValue)
    }

    // MARK: - Actions
    
    private func handleMoveToTrash() {
        let result = scanner.moveSelectedToTrash()
        
        switch result {
        case .success(let count):
            print("✅ \(count) file(s) moved to the Bin")
        case .failure(let error):
            print("❌ Error: \(error.localizedDescription)")
            // TODO: Present an error alert
        }
    }
    
    private func updateFocusedItem(from selection: Set<UUID>) {
        guard !selection.isEmpty else {
            focusedItemID = nil
            return
        }
        
        let source: [DesktopItem]
        switch selectedTab {
        case .toClean:
            source = scanner.items
        case .ignored:
            source = scanner.ignoredItems
        }
        
        if let first = source.first(where: { selection.contains($0.id) }) {
            focusItem(first.id)
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
    
    // MARK: - Quick Look
    
    private func currentSelectionURLs() -> [URL] {
        let source: [DesktopItem]
        switch selectedTab {
        case .toClean:
            source = scanner.items
        case .ignored:
            source = scanner.ignoredItems
        }
        
        let selected = source.filter { scanner.selectedItems.contains($0.id) }
        if !selected.isEmpty {
            return selected.map { $0.url }
        }
        
        if let focusedId = focusedItemID,
           let focusedItem = source.first(where: { $0.id == focusedId }) {
            return [focusedItem.url]
        }
        
        return []
    }
    
    private func focusItem(_ id: UUID) {
        focusedItemID = id
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

    // MARK: - Keyboard Handling

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
        // 1) Si on est dans un champ texte, on laisse macOS gérer
        if let responder = event.window?.firstResponder,
           responder is NSTextView {
            return event
        }
        
        // 2) On regarde les modifieurs (Cmd, Alt, Shift, Ctrl)
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
        
        switch event.keyCode {
        case 49: // Space
            if flags.isEmpty {
                previewSelectedItems()
                return nil // on “consomme” l’événement
            }
            
        case 51, 117: // Delete & Fn+Delete
            if flags.isEmpty, !scanner.selectedItems.isEmpty {
                // même comportement que le bouton "Move to Bin"
                showingDeleteConfirmation = true
                return nil // très important : on ne laisse pas macOS faire autre chose
            }
            
        default:
            break
        }
        
        return event
    }
}

#if DEBUG
#Preview("Main view") {
    ContentView(
        scanner: .preview(
            minDaysOld: 5,
            sortOption: .dateNewest
        )
    )
    .frame(width: 960, height: 800)
}

#Preview("Sort by size") {
    ContentView(
        scanner: .preview(
            itemsCount: 5,
            minDaysOld: 3,
            sortOption: .sizeDesc
        )
    )
    .frame(width: 960, height: 800)
}
#endif
