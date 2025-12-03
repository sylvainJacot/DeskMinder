import SwiftUI
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let popover = NSPopover()
    
    // On partage un scanner unique pour toute l’app
    let scanner = DesktopScanner()
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Icône barre de menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.title = ""
            button.action = #selector(togglePopover(_:))
        }
        
        // 2. Popover avec vue SwiftUI
        popover.behavior = .applicationDefined
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 0
        let popoverHeight = screenHeight > 0 ? screenHeight * 0.9 : 500
        popover.contentSize = NSSize(width: 420, height: popoverHeight)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(scanner: scanner)
        )
        NotificationManager.shared.requestAuthorization() // Appelé au lancement; lancer l’app via Xcode et dépasser le seuil pour tester les notifications.
        
        updateStatusItemCount(scanner.itemCount)
        
        scanner.$itemCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.updateStatusItemCount(count)
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
    
    private func updateStatusItemCount(_ count: Int) {
        guard let button = statusItem.button else { return }
        button.image = makeStatusImage(count: count)
        button.image?.isTemplate = false
    }
    
    private func makeStatusImage(count: Int) -> NSImage? {
        let symbolName = count > 0 ? "tray.full" : "tray"
        guard let baseSymbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: "DeskMinder") else {
            return nil
        }
        
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        guard let configuredSymbol = baseSymbol.withSymbolConfiguration(configuration) else {
            return nil
        }
        let baseImage = configuredSymbol.tinted(with: .white)
        
        let traySize = NSSize(width: 18, height: 18)
        baseImage.size = traySize
        
        let baseBadgeHeight: CGFloat = 22
        let spacing: CGFloat = count > 0 ? 8 : 0
        
        let badgeText: String
        if count > 999 {
            badgeText = "999+"
        } else {
            badgeText = "\(count)"
        }
        
        let fontSize: CGFloat = badgeText.count >= 3 ? 10 : 12
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: font,
            .paragraphStyle: paragraph
        ]
        
        let textSize = badgeText.size(withAttributes: attributes)
        let horizontalPadding: CGFloat = 6
        let badgeWidth = max(baseBadgeHeight, textSize.width + horizontalPadding)
        let width = traySize.width + spacing + (count > 0 ? badgeWidth : 0)
        let height = max(traySize.height, baseBadgeHeight)
        
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        
        let trayRect = NSRect(x: 0, y: (height - traySize.height) / 2, width: traySize.width, height: traySize.height)
        baseImage.draw(in: trayRect)
        
        if count > 0 {
            let badgeRect = NSRect(x: trayRect.maxX + spacing, y: (height - baseBadgeHeight) / 2, width: badgeWidth, height: baseBadgeHeight)
            let circlePath = NSBezierPath(ovalIn: badgeRect)
            NSColor.systemBlue.setFill()
            circlePath.fill()
            
            let textRect = badgeRect.insetBy(dx: 3, dy: 4)
            badgeText.draw(in: textRect, withAttributes: attributes)
        }
        
        image.unlockFocus()
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
