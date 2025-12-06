import AppKit
import Quartz

final class QuickLookPreviewCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var items: [URL] = []
    
    func updateItems(_ urls: [URL]) {
        items = urls
    }
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        items.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem {
        items[index] as NSURL
    }
}

