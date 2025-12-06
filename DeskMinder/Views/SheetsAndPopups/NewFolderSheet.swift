import SwiftUI

struct NewFolderSheet: View {
    @ObservedObject var scanner: DesktopScanner
    @Environment(\.dismiss) private var dismiss
    
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
