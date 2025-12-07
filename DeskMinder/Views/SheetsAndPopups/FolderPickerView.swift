import SwiftUI
import AppKit

struct FolderPickerView: View {
    @ObservedObject var scanner: DesktopScanner
    @Binding var showingNewFolderSheet: Bool
    @Environment(\.dismiss) private var dismiss
    
    private let commonFolders: [(name: String, url: URL?)] = {
        let fm = FileManager.default
        return [
            ("Documents", fm.urls(for: .documentDirectory, in: .userDomainMask).first),
            ("Pictures", fm.urls(for: .picturesDirectory, in: .userDomainMask).first),
            ("Downloads", fm.urls(for: .downloadsDirectory, in: .userDomainMask).first)
        ]
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Move to a folder")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick folders")
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
                    Text("Choose another folder...")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            Button {
                dismiss()
                showingNewFolderSheet = true
            } label: {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Create a new folder...")
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
        case "Pictures": return "photo.fill"
        case "Downloads": return "arrow.down.circle.fill"
        default: return "folder.fill"
        }
    }
    
    private func moveToFolder(_ url: URL) {
        let result = scanner.moveSelectedToFolder(url)
        
        switch result {
        case .success(let count):
            print("✅ \(count) file(s) moved")
            dismiss()
        case .failure(let error):
            print("❌ Error: \(error.localizedDescription)")
        }
    }
    
    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a destination folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            moveToFolder(url)
        }
    }
}
