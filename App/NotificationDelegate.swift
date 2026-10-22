import Foundation
import UserNotifications

/// What the user did with a notification, reduced to plain values so it can cross isolation boundaries.
struct NotificationResponse: Sendable {
    let action: String
    let userInfo: [String: String]
    let title: String
    let body: String
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let handler: @Sendable (NotificationResponse) -> Void

    init(handler: @escaping @Sendable (NotificationResponse) -> Void) {
        self.handler = handler
    }

    /// Show reminders even though the agent app may count as frontmost (for example with the popover open).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let userInfo = content.userInfo.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String { result[key] = value }
        }
        handler(NotificationResponse(
            action: response.actionIdentifier,
            userInfo: userInfo,
            title: content.title,
            body: content.body
        ))
        completionHandler()
    }
}
