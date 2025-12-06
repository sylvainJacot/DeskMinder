import Foundation
import Combine
import SwiftUI

class DesktopScanner: ObservableObject {
    static let allowedDaysRange: ClosedRange<Int> = 1...2000
    
    enum ScannerActionError: Error {
        case recommendedFolderUnavailable
    }
    
    @Published var items: [DesktopItem] = []
    @Published var ignoredItems: [DesktopItem] = []
    @Published private(set) var itemCount: Int = 0
    @Published private(set) var ignoredItemPaths: Set<String> = []
    @Published var selectedItems: Set<UUID> = [] {
        didSet {
            selectedItemsCount = selectedItems.count
        }
    }
    @Published private(set) var totalItemsCount: Int = 0
    @Published private(set) var selectedItemsCount: Int = 0
    @Published private(set) var ignoredItemsCount: Int = 0
    @Published private(set) var totalItemsSize: Int64 = 0
    @Published private(set) var formattedTotalSize: String = ByteCountFormatter.string(fromByteCount: 0, countStyle: .file)
    @Published private(set) var oldestItemAgeDescription: String?
    @Published var cleanlinessScore: DeskCleanlinessScore?
    @Published var sortOrder: [KeyPathComparator<DesktopItem>] = DesktopScanner.defaultSortOrder {
        didSet {
            applySortOrder()
        }
    }
    let fileCountThreshold = 15
    private let ignoredDefaultsKey = "ignoredDesktopItemPaths"
    
    /// Seuil minimal en jours pour considérer un fichier comme "ancien"
    @Published var minDaysOld: Int = 7 {
        didSet {
            let clampedValue = min(
                max(minDaysOld, DesktopScanner.allowedDaysRange.lowerBound),
                DesktopScanner.allowedDaysRange.upperBound
            )
            
            guard clampedValue == minDaysOld else {
                minDaysOld = clampedValue
                return
            }
            
            refresh()
        }
    }
    
    // Options de tri
    enum SortOption: String, CaseIterable {
        case nameAsc = "Nom (A-Z)"
        case nameDesc = "Nom (Z-A)"
        case dateOldest = "Plus ancien"
        case dateNewest = "Plus récent"
        case ageHighest = "Âge (décroissant)"
        case ageLowest = "Âge (croissant)"
        case sizeAsc = "Taille (croissant)"
        case sizeDesc = "Taille (décroissant)"
        case typeAsc = "Type (A-Z)"
        case typeDesc = "Type (Z-A)"
    }
    
    @Published var sortOption: SortOption = .dateOldest {
        didSet {
            sortOrder = sortOption.sortComparators
        }
    }
    
    private let fileManager = FileManager.default
    
    init() {
        loadIgnoredItems()
        refresh()
    }
    
    func refresh() {
        selectedItems.removeAll() // Désélectionner lors du refresh
        
        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            print("Impossible de trouver le dossier Desktop")
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: desktopURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            var filteredItems: [DesktopItem] = []
            var allItems: [DesktopItem] = []
            
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
                
                if resourceValues.isDirectory == true {
                    continue
                }
                
                guard let lastModified = resourceValues.contentModificationDate else {
                    continue
                }
                
                let item = DesktopItem(
                    url: url,
                    name: url.lastPathComponent,
                    lastModified: lastModified,
                    fileSize: resourceValues.fileSize ?? 0
                )
                
                allItems.append(item)
                
                if item.daysOld >= minDaysOld && !ignoredItemPaths.contains(item.url.path) {
                    filteredItems.append(item)
                }
            }
            
            let ignored = allItems.filter { self.ignoredItemPaths.contains($0.url.path) }
            
            DispatchQueue.main.async {
                self.items = filteredItems
                self.ignoredItems = ignored
                self.itemCount = filteredItems.count
                self.applySortOrder()
                self.updateCachedStats()
                self.updateCleanlinessScore(with: allItems)
                self.handleNotificationIfNeeded()
            }
            
        } catch {
            print("Erreur en lisant le Desktop : \(error)")
        }
    }
    
    private func handleNotificationIfNeeded() {
        guard items.count > fileCountThreshold else { return }
        NotificationManager.shared.sendTooManyFilesNotification(
            count: items.count,
            threshold: fileCountThreshold
        )
    }
    
    func applySortOrder() {
        items.sort(using: sortOrder)
        ignoredItems.sort(using: sortOrder)
    }
    
    private func updateCleanlinessScore(with desktopItems: [DesktopItem]) {
        guard !desktopItems.isEmpty else {
            cleanlinessScore = DeskCleanlinessScore(fileCount: 0, oldFileCount: 0, averageAge: 0)
            return
        }
        
        let fileCount = desktopItems.count
        let oldFileCount = desktopItems.filter { $0.daysOld >= minDaysOld }.count
        let averageAge = averageAge(for: desktopItems)
        cleanlinessScore = DeskCleanlinessScore(
            fileCount: fileCount,
            oldFileCount: oldFileCount,
            averageAge: averageAge
        )
    }
    
    private func averageAge(for items: [DesktopItem]) -> Double {
        guard !items.isEmpty else { return 0 }
        let totalDays = items.reduce(0.0) { partial, item in
            partial + Double(item.daysOld)
        }
        return totalDays / Double(items.count)
    }
    
    // MARK: - Sélection
    
    func toggleSelection(_ itemId: UUID) {
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
        } else {
            selectedItems.insert(itemId)
        }
    }
    
    func selectAll() {
        selectedItems = Set(items.map { $0.id })
    }
    
    func deselectAll() {
        selectedItems.removeAll()
    }
    
    var isAllSelected: Bool {
        !items.isEmpty && selectedItems.count == items.count
    }
    
    var selectedCount: Int {
        selectedItemsCount
    }
    
    var currentScore: DeskCleanlinessScore? {
        cleanlinessScore
    }
    
    // MARK: - Ignored Items
    
    func isIgnored(_ item: DesktopItem) -> Bool {
        ignoredItemPaths.contains(item.url.path)
    }
    
    func toggleIgnored(_ item: DesktopItem) {
        let path = item.url.path
        
        if ignoredItemPaths.contains(path) {
            ignoredItemPaths.remove(path)
        } else {
            ignoredItemPaths.insert(path)
        }
        
        saveIgnoredItems()
        refresh()
    }
    
    private func loadIgnoredItems() {
        let stored = UserDefaults.standard.stringArray(forKey: ignoredDefaultsKey) ?? []
        ignoredItemPaths = Set(stored)
    }
    
    private func saveIgnoredItems() {
        let array = Array(ignoredItemPaths)
        UserDefaults.standard.set(array, forKey: ignoredDefaultsKey)
    }
    
    // MARK: - Actions groupées
    
    func moveSelectedToTrash() -> Result<Int, Error> {
        let itemsToDelete = items.filter { selectedItems.contains($0.id) }
        var successCount = 0
        
        for item in itemsToDelete {
            do {
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                successCount += 1
            } catch {
                print("Erreur lors de la mise à la corbeille de \(item.name): \(error)")
                return .failure(error)
            }
        }
        
        // Refresh après suppression
        refresh()
        
        return .success(successCount)
    }
    
    func moveSelectedToFolder(_ destinationURL: URL) -> Result<Int, Error> {
        let itemsToMove = items.filter { selectedItems.contains($0.id) }
        var successCount = 0
        
        for item in itemsToMove {
            let destination = destinationURL.appendingPathComponent(item.name)
            
            do {
                // Gérer les conflits de noms
                var finalDestination = destination
                var counter = 1
                
                while fileManager.fileExists(atPath: finalDestination.path) {
                    let nameWithoutExt = item.url.deletingPathExtension().lastPathComponent
                    let ext = item.url.pathExtension
                    let newName = ext.isEmpty ? "\(nameWithoutExt) \(counter)" : "\(nameWithoutExt) \(counter).\(ext)"
                    finalDestination = destinationURL.appendingPathComponent(newName)
                    counter += 1
                }
                
                try fileManager.moveItem(at: item.url, to: finalDestination)
                successCount += 1
            } catch {
                print("Erreur lors du déplacement de \(item.name): \(error)")
                return .failure(error)
            }
        }
        
        // Refresh après déplacement
        refresh()
        
        return .success(successCount)
    }
    
    func createFolderAndMove(folderName: String, in parentURL: URL) -> Result<URL, Error> {
        let newFolderURL = parentURL.appendingPathComponent(folderName)
        
        do {
            // Créer le dossier s'il n'existe pas
            if !fileManager.fileExists(atPath: newFolderURL.path) {
                try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: false)
            }
            
            // Déplacer les fichiers
            let result = moveSelectedToFolder(newFolderURL)
            
            switch result {
            case .success:
                return .success(newFolderURL)
            case .failure(let error):
                return .failure(error)
            }
        } catch {
            return .failure(error)
        }
    }
    
    func moveSelectionToRecommendedFolder() -> Result<URL, Error> {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return .failure(ScannerActionError.recommendedFolderUnavailable)
        }
        return createFolderAndMove(folderName: "DeskMinder - Tri", in: documents)
    }
}

private extension DesktopScanner {
    func updateCachedStats() {
        totalItemsCount = items.count
        ignoredItemsCount = ignoredItems.count
        totalItemsSize = items.reduce(Int64(0)) { partial, item in
            partial + Int64(item.fileSize)
        }
        formattedTotalSize = ByteCountFormatter.string(
            fromByteCount: totalItemsSize,
            countStyle: .file
        )
        oldestItemAgeDescription = Self.makeOldestItemDescription(from: items)
    }
    
    static func makeOldestItemDescription(from items: [DesktopItem]) -> String? {
        guard let maxDays = items.map(\.daysOld).max() else { return nil }
        switch maxDays {
        case 0:
            return "Aujourd'hui"
        case 1:
            return "1 jour"
        default:
            return "\(maxDays) jours"
        }
    }
}

private extension DesktopScanner {
    static let defaultSortOrder: [KeyPathComparator<DesktopItem>] = SortOption.dateOldest.sortComparators
}

private extension DesktopScanner.SortOption {
    var sortComparators: [KeyPathComparator<DesktopItem>] {
        switch self {
        case .nameAsc:
            return [.init(\DesktopItem.displayName, order: .forward)]
        case .nameDesc:
            return [.init(\DesktopItem.displayName, order: .reverse)]
        case .dateOldest:
            return [.init(\DesktopItem.modificationDate, order: .forward)]
        case .dateNewest:
            return [.init(\DesktopItem.modificationDate, order: .reverse)]
        case .ageHighest:
            return [.init(\DesktopItem.daysOld, order: .reverse)]
        case .ageLowest:
            return [.init(\DesktopItem.daysOld, order: .forward)]
        case .sizeAsc:
            return [.init(\DesktopItem.fileSize, order: .forward)]
        case .sizeDesc:
            return [.init(\DesktopItem.fileSize, order: .reverse)]
        case .typeAsc:
            return [.init(\DesktopItem.fileExtension, order: .forward)]
        case .typeDesc:
            return [.init(\DesktopItem.fileExtension, order: .reverse)]
        }
    }
}

#if DEBUG
extension DesktopScanner {
    static func preview(
        itemsCount: Int? = nil,
        minDaysOld: Int = 7,
        sortOption: SortOption = .dateOldest,
        ignoredPaths: Set<String>? = nil
    ) -> DesktopScanner {
        let availableItems = DesktopItem.previewItems
        guard !availableItems.isEmpty else {
            return DesktopScannerPreview(
                items: [],
                ignoredPaths: [],
                minDaysOld: minDaysOld,
                sortOption: sortOption
            )
        }
        
        let targetCount = itemsCount ?? availableItems.count
        let clampedCount = min(max(targetCount, 1), availableItems.count)
        let selectedItems = Array(availableItems.prefix(clampedCount))
        let baseIgnoredPaths = ignoredPaths ?? DesktopItem.previewIgnoredPaths
        let filteredIgnoredPaths = Set(
            baseIgnoredPaths.filter { path in
                selectedItems.contains { $0.url.path == path }
            }
        )
        
        return DesktopScannerPreview(
            items: selectedItems,
            ignoredPaths: filteredIgnoredPaths,
            minDaysOld: minDaysOld,
            sortOption: sortOption
        )
    }
    
    fileprivate func setPreviewItemCount(_ count: Int) {
        self.itemCount = count
    }
    
    fileprivate func setPreviewIgnoredPaths(_ paths: Set<String>) {
        self.ignoredItemPaths = paths
    }
}

private final class DesktopScannerPreview: DesktopScanner {
    private let previewItemsData: [DesktopItem]
    
    init(
        items: [DesktopItem],
        ignoredPaths: Set<String>,
        minDaysOld: Int,
        sortOption: SortOption
    ) {
        self.previewItemsData = items
        super.init()
        setPreviewIgnoredPaths(ignoredPaths)
        self.sortOption = sortOption
        self.minDaysOld = minDaysOld
    }
    
    override func refresh() {
        applyPreviewData()
    }
    
    private func applyPreviewData() {
        let filteredItems = previewItemsData.filter {
            $0.daysOld >= minDaysOld && !ignoredItemPaths.contains($0.url.path)
        }
        let ignoredItems = previewItemsData.filter {
            ignoredItemPaths.contains($0.url.path)
        }
        
        self.items = filteredItems
        self.ignoredItems = ignoredItems
        setPreviewItemCount(filteredItems.count)
        self.cleanlinessScore = DeskCleanlinessScore(
            fileCount: previewItemsData.count,
            oldFileCount: previewItemsData.filter { $0.daysOld >= minDaysOld }.count,
            averageAge: DesktopScannerPreview.averageAge(for: previewItemsData)
        )
        selectedItems.removeAll()
        updateCachedStats()
        applySortOrder()
    }
    
    private static func averageAge(for items: [DesktopItem]) -> Double {
        guard !items.isEmpty else { return 0 }
        let totalDays = items.reduce(0.0) { $0 + Double($1.daysOld) }
        return totalDays / Double(items.count)
    }
}
#endif
