import SwiftUI
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let popover = NSPopover()
    
    // Share a single scanner across the entire app
    let scanner = DesktopScanner()
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.title = ""
            button.action = #selector(togglePopover(_:))
        }
        
        // 2. Popover with SwiftUI view
        popover.behavior = .applicationDefined
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 0
        let popoverHeight = screenHeight > 0 ? screenHeight * 0.9 : 500
        popover.contentSize = NSSize(width: 420, height: popoverHeight)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(scanner: scanner)
        )
        NotificationManager.shared.requestAuthorization() // Request permissions when the app launches.
        
        updateStatusItem(for: scanner.cleanlinessScore)
        
        scanner.$cleanlinessScore
            .receive(on: RunLoop.main)
            .sink { [weak self] score in
                self?.updateStatusItem(for: score)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenPopoverRequest),
            name: .deskMinderShowPopover,
            object: nil
        )
    }
    
    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }
    
    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    
    @objc private func handleOpenPopoverRequest() {
        showPopover()
    }
    
    private func updateStatusItem(for score: DeskCleanlinessScore?) {
        guard let button = statusItem.button else { return }
        
        guard let score = score else {
            button.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "DeskMinder")
            button.image?.isTemplate = true
            return
        }
        
        let baseSymbolName = score.fileCount > 0 ? "tray.full" : "tray"
        let overlay: NSImage?
        switch score.level {
        case .good:
            overlay = makeCheckBadgeImage()
        case .medium:
            overlay = makeBadgeStatusImage(count: score.fileCount, color: .systemOrange)
        case .bad:
            overlay = makeBadgeStatusImage(count: score.fileCount, color: .systemRed)
        }
        
        if let image = makeStatusCompositeImage(baseSymbolName: baseSymbolName, overlay: overlay) {
            button.image = image
            button.image?.isTemplate = false
        } else {
            button.image = NSImage(systemSymbolName: baseSymbolName, accessibilityDescription: "DeskMinder")
            button.image?.isTemplate = true
        }
    }
    
    private func makeStatusCompositeImage(baseSymbolName: String, overlay: NSImage?, spacing: CGFloat = 6) -> NSImage? {
        guard let baseSymbol = NSImage(systemSymbolName: baseSymbolName, accessibilityDescription: "DeskMinder") else {
            return nil
        }
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let configuredBase = baseSymbol.withSymbolConfiguration(configuration)?.tinted(with: .white) ?? baseSymbol
        let baseSize = NSSize(width: 18, height: 18)
        configuredBase.size = baseSize
        
        let overlaySize = overlay?.size ?? .zero
        let width = baseSize.width + (overlay != nil ? spacing + overlaySize.width : 0)
        let height = max(baseSize.height, overlaySize.height)
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        
        let baseRect = NSRect(
            x: 0,
            y: (height - baseSize.height) / 2,
            width: baseSize.width,
            height: baseSize.height
        )
        configuredBase.draw(in: baseRect)
        
        if let overlay = overlay {
            let overlayRect = NSRect(
                x: baseRect.maxX + spacing,
                y: (height - overlaySize.height) / 2,
                width: overlaySize.width,
                height: overlaySize.height
            )
            overlay.draw(in: overlayRect)
        }
        
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
    
    private func makeCheckBadgeImage() -> NSImage? {
        guard let baseSymbol = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Clean desktop") else {
            return nil
        }
        
        let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        guard let configuredSymbol = baseSymbol.withSymbolConfiguration(configuration)?.tinted(with: .white) else {
            return nil
        }
        
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: size.height / 2, yRadius: size.height / 2)
        NSColor.systemGreen.setFill()
        path.fill()
        
        let symbolRect = rect.insetBy(dx: 4, dy: 4)
        configuredSymbol.draw(in: symbolRect)
        
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
    
    private func makeBadgeStatusImage(count: Int, color: NSColor) -> NSImage? {
        let clampedCount = max(0, count)
        let text = clampedCount > 999 ? "999+" : "\(clampedCount)"
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 6
        let size = NSSize(width: max(18, textSize.width + padding * 2), height: 18)
        
        let image = NSImage(size: size)
        image.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: size.height / 2, yRadius: size.height / 2)
        color.setFill()
        path.fill()
        
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        (text as NSString).draw(in: textRect, withAttributes: textAttributes)
        
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

private extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        color.set()
        rect.fill()
        draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
