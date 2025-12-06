import SwiftUI
import AppKit
import QuickLookThumbnailing

struct FileThumbnailView: View {
    let url: URL
    private let size: CGFloat = 32
    
    @State private var thumbnail: NSImage?
    @State private var isGenerating = false
    
    var body: some View {
        Image(nsImage: thumbnail ?? fallbackIcon)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .cornerRadius(4)
            .onAppear(perform: generateThumbnailIfNeeded)
            .onChange(of: url) { _ in
                thumbnail = nil
                generateThumbnailIfNeeded()
            }
    }
    
    private var fallbackIcon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
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

