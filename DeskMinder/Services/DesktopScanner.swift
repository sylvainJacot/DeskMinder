import Foundation
import Combine
import SwiftUI
import AppKit

class DesktopScanner: ObservableObject {
    static let allowedDaysRange: ClosedRange<Int> = 1...2000
    
    @Published var items: [DesktopItem] = []
    @Published var ignoredItems: [DesktopItem] = []
    @Published private(set) var itemCount: Int = 0
    @Published private(set) var ignoredItemPaths: Set<String> = []
    @Published var selectedItems: Set<UUID> = [] {
        didSet {
            selectedItemsCount = selectedItems.count
            updateSelectedStats()
        }
    }
    @Published private(set) var totalItemsCount: Int = 0
    @Published private(set) var selectedItemsCount: Int = 0
    @Published private(set) var ignoredItemsCount: Int = 0
    @Published private(set) var totalItemsSize: Int64 = 0
    @Published private(set) var formattedTotalSize: String = ByteCountFormatter.string(fromByteCount: 0, countStyle: .file)
    @Published private(set) var selectedItemsSize: Int64 = 0
    @Published private(set) var formattedSelectedTotalSize: String = ByteCountFormatter.string(fromByteCount: 0, countStyle: .file)
    @Published private(set) var oldestItemAgeDescription: String?
    @Published var cleanlinessScore: DeskCleanlinessScore?
    @Published var sortOrder: [KeyPathComparator<DesktopItem>] = DesktopScanner.defaultSortOrder {
        didSet {
            applySortOrder()
        }
    }
    let fileCountThreshold = 15
    private let ignoredDefaultsKey = "ignoredDesktopItemPaths"
    
    /// Minimum age in days for a file to be considered "old"
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
    
    enum SortOption: String, CaseIterable {
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case dateOldest = "Oldest first"
        case dateNewest = "Newest first"
        case ageHighest = "Age (descending)"
        case ageLowest = "Age (ascending)"
        case sizeAsc = "Size (ascending)"
        case sizeDesc = "Size (descending)"
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
        selectedItems.removeAll() // Clear selection when refreshing
        
        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            print("Unable to locate the Desktop folder")
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
                    lastModified: lastModified,
                    fileSize: Int64(resourceValues.fileSize ?? 0)
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
            print("Error while reading the Desktop: \(error)")
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
        let actionableItems = items
        guard !actionableItems.isEmpty else {
            cleanlinessScore = DeskCleanlinessScore(fileCount: 0, oldFileCount: 0, averageAge: 0)
            return
        }
        
        let fileCount = actionableItems.count
        let oldAgeThreshold = minDaysOld + 14
        let oldFileCount = actionableItems.filter { $0.daysOld >= oldAgeThreshold }.count
        let averageAge = averageAge(for: actionableItems)
        let scoreValue = DeskCleanlinessScore.computeScore(
            fileCount: fileCount,
            oldFileCount: oldFileCount,
            averageAge: averageAge
        )
        cleanlinessScore = DeskCleanlinessScore(
            fileCount: fileCount,
            oldFileCount: oldFileCount,
            averageAge: averageAge,
            score: scoreValue
        )
    }
    
    private func averageAge(for items: [DesktopItem]) -> Double {
        guard !items.isEmpty else { return 0 }
        let totalDays = items.reduce(0.0) { partial, item in
            partial + Double(item.daysOld)
        }
        return totalDays / Double(items.count)
    }
    
    // MARK: - Selection
    
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
    
    // MARK: - Bulk actions
    
    func moveSelectedToTrash() -> Result<Int, Error> {
        let itemsToDelete = items.filter { selectedItems.contains($0.id) }
        var successCount = 0
        
        for item in itemsToDelete {
            do {
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                successCount += 1
            } catch {
                print("Error moving \(item.displayName) to the Trash: \(error)")
                return .failure(error)
            }
        }
        
        // Refresh after deletion
        refresh()
        
        return .success(successCount)
    }
    
    func moveAllToTrash() -> Result<Int, Error> {
        guard !items.isEmpty else {
            return .success(0)
        }
        
        var successCount = 0
        
        for item in items {
            do {
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                successCount += 1
            } catch {
                print("Error moving \(item.displayName) to the Trash: \(error)")
                return .failure(error)
            }
        }
        
        refresh()
        
        return .success(successCount)
    }
    
    func moveSelectedToFolder(_ destinationURL: URL) -> Result<Int, Error> {
        let itemsToMove = items.filter { selectedItems.contains($0.id) }
        var successCount = 0
        
        for item in itemsToMove {
            let destination = destinationURL.appendingPathComponent(item.displayName)
            
            do {
                // Handle duplicate file names
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
                print("Error while moving \(item.displayName): \(error)")
                return .failure(error)
            }
        }
        
        // Refresh after moving
        refresh()
        
        return .success(successCount)
    }
    
    func createFolderAndMove(folderName: String, in parentURL: URL) -> Result<URL, Error> {
        let newFolderURL = parentURL.appendingPathComponent(folderName)
        
        do {
            // Create the folder if it does not exist
            if !fileManager.fileExists(atPath: newFolderURL.path) {
                try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: false)
            }
            
            // Move the files
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
    
}

private extension DesktopScanner {
    func updateCachedStats() {
        totalItemsCount = items.count
        ignoredItemsCount = ignoredItems.count
        totalItemsSize = items.reduce(Int64(0)) { partial, item in
            partial + item.fileSize
        }
        formattedTotalSize = ByteCountFormatter.string(
            fromByteCount: totalItemsSize,
            countStyle: .file
        )
        oldestItemAgeDescription = Self.makeOldestItemDescription(from: items)
        updateSelectedStats()
    }

    private func updateSelectedStats() {
        let selected = items.filter { selectedItems.contains($0.id) }
        selectedItemsSize = selected.reduce(Int64(0)) { $0 + $1.fileSize }
        formattedSelectedTotalSize = ByteCountFormatter.string(
            fromByteCount: selectedItemsSize,
            countStyle: .file
        )
    }
    
    static func makeOldestItemDescription(from items: [DesktopItem]) -> String? {
        guard let maxDays = items.map(\.daysOld).max() else { return nil }
        switch maxDays {
        case 0:
            return "Today"
        case 1:
            return "1 day"
        default:
            return "\(maxDays) days"
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
            return [.init(\DesktopItem.lastModified, order: .forward)]
        case .dateNewest:
            return [.init(\DesktopItem.lastModified, order: .reverse)]
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
        let previewFileCount = filteredItems.count
        let previewOldFileThreshold = minDaysOld + 14
        let previewOldFileCount = filteredItems.filter { $0.daysOld >= previewOldFileThreshold }.count
        let previewAverageAge = DesktopScannerPreview.averageAge(for: filteredItems)
        let previewScore = DeskCleanlinessScore.computeScore(
            fileCount: previewFileCount,
            oldFileCount: previewOldFileCount,
            averageAge: previewAverageAge
        )
        self.cleanlinessScore = DeskCleanlinessScore(
            fileCount: previewFileCount,
            oldFileCount: previewOldFileCount,
            averageAge: previewAverageAge,
            score: previewScore
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
