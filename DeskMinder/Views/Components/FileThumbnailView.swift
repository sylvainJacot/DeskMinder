import SwiftUI
import AppKit
import QuickLookThumbnailing

struct FileThumbnailView: View {
    let url: URL
    private let size: CGFloat = 32
    
    @State private var thumbnail: NSImage?
    @State private var defaultIcon: NSImage = NSImage()
    @State private var isGenerating = false
    
    var body: some View {
        Image(nsImage: thumbnail ?? defaultIcon)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .cornerRadius(6)
            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
            .padding(.leading, 4)
            .onAppear {
                loadDefaultIcon()
                generateThumbnailIfNeeded()
            }
            .onChange(of: url) { _ in
                thumbnail = nil
                loadDefaultIcon()
                generateThumbnailIfNeeded()
            }
    }
    
    private func loadDefaultIcon() {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        defaultIcon = icon
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
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            DispatchQueue.main.async {
                self.isGenerating = false
                if let image = representation?.nsImage {
                    self.thumbnail = image
                }
            }
        }
    }
}
