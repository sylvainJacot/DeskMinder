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
        let ext = url.pathExtension.lowercased()
        if let cached = ThumbnailCache.shared.icon(forFileExtension: ext) {
            defaultIcon = cached
            return
        }
        
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        defaultIcon = icon
        ThumbnailCache.shared.setIcon(icon, forFileExtension: ext)
    }
    
    private func generateThumbnailIfNeeded() {
        if let cached = ThumbnailCache.shared.thumbnail(for: url) {
            thumbnail = cached
            return
        }
        
        guard thumbnail == nil, !isGenerating else { return }
        isGenerating = true
        let currentURL = url
        
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: currentURL,
            size: CGSize(width: size, height: size),
            scale: scale,
            representationTypes: .all
        )
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            DispatchQueue.main.async {
                self.isGenerating = false
                guard currentURL == self.url else { return }
                if let image = representation?.nsImage {
                    self.thumbnail = image
                    ThumbnailCache.shared.setThumbnail(image, for: currentURL)
                }
            }
        }
    }
}
