import Foundation
import UserNotifications

/// Tells the user something when Signa cannot quietly handle it alone.
public protocol UserNotifying: Sendable {
    func notify(title: String, body: String)
}

public struct SystemNotifier: UserNotifying {
    public init() {}

    public func notify(title: String, body: String) {
        // Notifications are tied to an application bundle.
        guard Bundle.main.bundleIdentifier != nil else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            // Asked for only now, the first time there is something worth saying.
            guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            try? await center.add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
