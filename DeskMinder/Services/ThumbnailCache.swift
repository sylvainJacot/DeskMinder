import AppKit

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    private let thumbnailCache = NSCache<NSURL, NSImage>()
    private let iconCache = NSCache<NSString, NSImage>()
    
    private init() {}
    
    func thumbnail(for url: URL) -> NSImage? {
        thumbnailCache.object(forKey: url as NSURL)
    }
    
    func setThumbnail(_ image: NSImage, for url: URL) {
        thumbnailCache.setObject(image, forKey: url as NSURL)
    }
    
    func removeThumbnail(for url: URL) {
        thumbnailCache.removeObject(forKey: url as NSURL)
    }
    
    func clear() {
        thumbnailCache.removeAllObjects()
        iconCache.removeAllObjects()
    }
    
    func icon(forFileExtension ext: String) -> NSImage? {
        iconCache.object(forKey: ext as NSString)
    }
    
    func setIcon(_ image: NSImage, forFileExtension ext: String) {
        iconCache.setObject(image, forKey: ext as NSString)
    }
}
