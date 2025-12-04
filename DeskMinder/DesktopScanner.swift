import Foundation
import Combine

class DesktopScanner: ObservableObject {
    static let allowedDaysRange: ClosedRange<Int> = 1...2000
    
    @Published var items: [DesktopItem] = []
    @Published var ignoredItems: [DesktopItem] = []
    @Published private(set) var itemCount: Int = 0
    @Published private(set) var ignoredItemPaths: Set<String> = []
    @Published var selectedItems: Set<UUID> = []
    @Published var cleanlinessScore: DeskCleanlinessScore?
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
    }
    
    @Published var sortOption: SortOption = .dateOldest {
        didSet {
            applySorting()
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
                self.applySorting()
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
    
    private func applySorting() {
        switch sortOption {
        case .nameAsc:
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .dateOldest:
            items.sort { $0.lastModified < $1.lastModified }
        case .dateNewest:
            items.sort { $0.lastModified > $1.lastModified }
        case .ageHighest:
            items.sort { $0.daysOld > $1.daysOld }
        case .ageLowest:
            items.sort { $0.daysOld < $1.daysOld }
        }
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
        selectedItems.count
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
}
