import Foundation

struct DesktopItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let lastModified: Date
    let fileSize: Int
    
    var daysOld: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: lastModified, to: Date())
        return components.day ?? 0
    }
    
    var formattedFileSize: String {
        DesktopItem.sizeFormatter.string(fromByteCount: Int64(fileSize))
    }
    
    var fileExtension: String {
        url.pathExtension.lowercased()
    }
    
    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()
}
