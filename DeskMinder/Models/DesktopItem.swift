import Foundation

struct DesktopItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let lastModified: Date
    let fileSize: Int
    
    var displayName: String {
        name
    }
    
    var modificationDate: Date {
        lastModified
    }
    
    var daysOld: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: lastModified, to: Date())
        return components.day ?? 0
    }
    
    var formattedFileSize: String {
        DesktopItem.sizeFormatter.string(fromByteCount: Int64(fileSize))
    }
    
    var formattedModificationDate: String {
        DesktopItem.dateFormatter.string(from: modificationDate)
    }
    
    var formattedLastModified: String {
        DesktopItem.dateFormatter.string(from: lastModified)
    }
    
    var fileExtension: String {
        let ext = url.pathExtension.uppercased()
        return ext.isEmpty ? "—" : ext
    }
    
    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#if DEBUG
extension DesktopItem {
    /// Jeux de données statiques pour alimenter les previews SwiftUI.
    static var previewItems: [DesktopItem] {
        [
            DesktopItem.preview(
                name: "TODO.txt",
                daysOld: 3,
                sizeInKB: 12
            ),
            DesktopItem.preview(
                name: "Facture-Janvier.pdf",
                daysOld: 42,
                sizeInKB: 320
            ),
            DesktopItem.preview(
                name: "Présentation.key",
                daysOld: 18,
                sizeInKB: 9_850
            ),
            DesktopItem.preview(
                name: "Moodboard.sketch",
                daysOld: 65,
                sizeInKB: 2_048
            ),
            DesktopItem.preview(
                name: "Capture.png",
                daysOld: 12,
                sizeInKB: 940
            ),
            DesktopItem.preview(
                name: "Archive-Projet.zip",
                daysOld: 110,
                sizeInKB: 32_768
            ),
            DesktopItem.preview(
                name: "ArticleDraft.md",
                daysOld: 27,
                sizeInKB: 180
            ),
            DesktopItem.preview(
                name: "Photo-Session.jpg",
                daysOld: 9,
                sizeInKB: 5_100
            )
        ]
    }
    
    static var previewIgnoredPaths: Set<String> {
        let names = [
            "Facture-Janvier.pdf",
            "Archive-Projet.zip"
        ]
        return Set(
            names.map { previewURL(for: $0).path }
        )
    }
    
    private static func preview(
        name: String,
        daysOld: Int,
        sizeInKB: Int
    ) -> DesktopItem {
        let baseURL = URL(fileURLWithPath: "/Users/preview/Desktop", isDirectory: true)
        let fileURL = baseURL.appendingPathComponent(name)
        let lastModified = Calendar.current.date(byAdding: .day, value: -daysOld, to: Date()) ?? Date()
        return DesktopItem(
            url: fileURL,
            name: name,
            lastModified: lastModified,
            fileSize: sizeInKB * 1_024
        )
    }
    
    private static func previewURL(for name: String) -> URL {
        let baseURL = URL(fileURLWithPath: "/Users/preview/Desktop", isDirectory: true)
        return baseURL.appendingPathComponent(name)
    }
}
#endif
