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
    
    /// Appelez requestAuthorization() dans AppDelegate.applicationDidFinishLaunching depuis Xcode,
    /// puis dépassez le seuil depuis DesktopScanner pour tester l’affichage des notifications locales.
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Erreur lors de la demande d’autorisation de notification : \(error)")
            } else if !granted {
                print("L’utilisateur a refusé les notifications DeskMinder.")
            }
        }
    }
    
    func sendTooManyFilesNotification(count: Int, threshold: Int) {
        guard count > threshold else { return }
        guard shouldSendNotificationToday() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Votre bureau commence à être encombré 🧹"
        content.subtitle = "Vous avez \(count) fichiers sur votre bureau."
        content.body = "Pensez à jeter un coup d'œil : certains ont peut-être dépassé votre seuil de conservation."
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                print("Erreur lors de la programmation de la notification DeskMinder : \(error)")
            } else if let self = self {
                self.userDefaults.set(Date(), forKey: self.lastNotificationKey)
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
            title: "Ouvrir DeskMinder",
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
