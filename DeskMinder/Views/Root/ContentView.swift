import SwiftUI
import AppKit
import Quartz

struct ContentView: View {
    enum ListTab: String, CaseIterable, Identifiable {
        case toClean
        case ignored
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .toClean: return "À ranger"
            case .ignored: return "Ignorés"
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
            case .days:   return "jours"
            case .months: return "mois"
            case .years:  return "ans"
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
                return value == 1 ? "1 jour" : "\(value) jours"
            case .months:
                return value == 1 ? "1 mois" : "\(value) mois"
            case .years:
                return value == 1 ? "1 an" : "\(value) ans"
            }
        }
    }
    
    @ObservedObject var scanner: DesktopScanner
    @State private var showingDeleteConfirmation = false
    @State private var showingFolderPicker = false
    @State private var showingNewFolderSheet = false
    @State private var spaceKeyMonitor: Any?
    @State private var focusedItemID: UUID?
    @State private var selectedTab: ListTab = .toClean
    @State private var thresholdValue: Int = 7
    @State private var thresholdUnit: ThresholdUnit = .days
    private let quickLookCoordinator = QuickLookPreviewCoordinator()
    
    var body: some View {
        VStack(spacing: 0) {
            ContentHeaderView(
                scanner: scanner,
                thresholdValue: $thresholdValue,
                thresholdUnit: $thresholdUnit,
                onThresholdChange: applyThresholdChange
            )
            ContentExplorerView(
                scanner: scanner,
                selectedTab: $selectedTab,
                focusedItemID: $focusedItemID,
                showingFolderPicker: $showingFolderPicker,
                showingNewFolderSheet: $showingNewFolderSheet,
                showingDeleteConfirmation: $showingDeleteConfirmation,
                focusItem: focusItem(_:)
            )
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
            syncFromScanner()
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
    
    // MARK: - Threshold Helpers
    
    private func syncFromScanner() {
        let days = scanner.minDaysOld
        
        if days % 365 == 0 && days >= 365 {
            thresholdUnit = .years
            thresholdValue = max(days / 365, 1)
        } else if days % 30 == 0 && days >= 30 {
            thresholdUnit = .months
            thresholdValue = max(days / 30, 1)
        } else {
            thresholdUnit = .days
            thresholdValue = max(days, 1)
        }
    }
    
    private func applyThresholdChange() {
        let rawDays = thresholdUnit.toDays(thresholdValue)
        let clampedDays = min(
            max(rawDays, DesktopScanner.allowedDaysRange.lowerBound),
            DesktopScanner.allowedDaysRange.upperBound
        )
        scanner.minDaysOld = clampedDays
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
    
    // MARK: - Quick Look
    
    private func currentSelectionURLs() -> [URL] {
        if let focusedId = focusedItemID,
           let focusedItem = item(for: focusedId) {
            return [focusedItem.url]
        }
        
        if selectedTab == .toClean {
            let selected = scanner.items.filter { scanner.selectedItems.contains($0.id) }
            if !selected.isEmpty {
                return selected.map { $0.url }
            }
        }
        
        return []
    }
    
    private func item(for id: UUID) -> DesktopItem? {
        if let match = scanner.items.first(where: { $0.id == id }) {
            return match
        }
        return scanner.ignoredItems.first(where: { $0.id == id })
    }
    
    private func focusItem(_ id: UUID) {
        NSApp.keyWindow?.makeFirstResponder(nil)
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
