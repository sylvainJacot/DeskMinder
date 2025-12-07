import Foundation
import Combine
import UserNotifications

final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    let objectWillChange = ObservableObjectPublisher()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private let lastNotificationKey = "DeskMinderLastNotificationDate"
    private let notificationIdentifier = "DeskMinderTooManyFiles"
    private let categoryIdentifier = "DeskMinderTooManyFilesCategory"
    private let openActionIdentifier = "DeskMinderOpenAction"
    private let calendar = Calendar.current
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
        registerCategory()
    }
    
    /// Call requestAuthorization() from AppDelegate.applicationDidFinishLaunching,
    /// then exceed the threshold via DesktopScanner to test local notifications.
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            } else if !granted {
                print("The user denied DeskMinder notifications.")
            }
        }
    }
    
    func sendTooManyFilesNotification(count: Int, threshold: Int) {
        guard count > threshold else { return }
        guard shouldSendNotificationToday() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Your desktop is getting cluttered 🧹"
        content.subtitle = "You currently have \(count) files on your desktop."
        content.body = "Take a look - some of them might already be older than your retention threshold."
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                print("Error scheduling the DeskMinder notification: \(error)")
            } else if let self = self {
                self.userDefaults.set(Date(), forKey: self.lastNotificationKey)
            }
        }
    }
    
    func sendFilesMovedNotification(count: Int, destinationDescription: String) {
        let content = UNMutableNotificationContent()
        content.title = "Files organized"
        if count == 1 {
            content.body = "1 file was moved to \(destinationDescription)."
        } else {
            content.body = "\(count) files were moved to \(destinationDescription)."
        }
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling the DeskMinder notification: \(error)")
            }
        }
    }
    
    private func shouldSendNotificationToday() -> Bool {
        guard let lastDate = userDefaults.object(forKey: lastNotificationKey) as? Date else {
            return true
        }
        
        return !calendar.isDate(Date(), inSameDayAs: lastDate)
    }
    
    private func registerCategory() {
        let openAction = UNNotificationAction(
            identifier: openActionIdentifier,
            title: "Open DeskMinder",
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([category])
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == openActionIdentifier || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .deskMinderShowPopover, object: nil)
            }
        }
        
        completionHandler()
    }
}

extension Notification.Name {
    static let deskMinderShowPopover = Notification.Name("DeskMinderShowPopoverNotification")
}
