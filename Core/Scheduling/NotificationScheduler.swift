import Foundation
import UserNotifications

public enum NotificationAuthorization: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
}

public struct AlertRequest: Sendable, Equatable {
    public let id: String
    public let fireDate: Date
    public let title: String
    public let body: String
    public let sound: Bool
    public let categoryID: String
    public let userInfo: [String: String]

    public init(id: String, fireDate: Date, title: String, body: String, sound: Bool, categoryID: String, userInfo: [String: String]) {
        self.id = id
        self.fireDate = fireDate
        self.title = title
        self.body = body
        self.sound = sound
        self.categoryID = categoryID
        self.userInfo = userInfo
    }
}

/// Seam over `UNUserNotificationCenter` so scheduling is tested without delivering anything.
public protocol NotificationCenterProtocol: Sendable {
    func authorizationStatus() async -> NotificationAuthorization
    func requestAuthorization() async -> Bool
    func registerCategories(joinTitle: String, snoozeTitle: String) async
    func add(_ request: AlertRequest) async
    func pendingIdentifiers(prefix: String) async -> [String]
    func removePending(identifiers: [String]) async
}

public enum NotificationIDs {
    public static let joinAction = "nc.action.join"
    public static let snoozeAction = "nc.action.snooze"
    public static let joinCategory = "nc.category.join"
    public static let snoozeOnlyCategory = "nc.category.snooze"
    public static let snoozePrefix = "ncs."
}

/// What the notification body and title say; localized by the app.
public struct AlertText: Sendable, Equatable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// Keys of the notification's `userInfo`, which carries everything needed to join or snooze
/// without reading the calendar again.
public enum AlertPayload {
    public static func userInfo(for meeting: Meeting) -> [String: String] {
        var info = ["meetingID": meeting.id, "end": String(meeting.end.timeIntervalSinceReferenceDate)]
        if let link = meeting.link {
            info["provider"] = link.provider.rawValue
            info["url"] = link.url.absoluteString
            if let native = link.nativeURL { info["native"] = native.absoluteString }
        }
        return info
    }

    public static func link(from userInfo: [String: String]) -> MeetingLink? {
        guard let raw = userInfo["provider"], let provider = Provider(rawValue: raw),
              let urlString = userInfo["url"], let url = URL(string: urlString)
        else { return nil }
        return MeetingLink(provider: provider, url: url, nativeURL: userInfo["native"].flatMap { URL(string: $0) })
    }
}

/// Keeps the system's pending reminders in step with the plan from `AlertPlanner`.
@MainActor
public final class NotificationScheduler {
    private let center: any NotificationCenterProtocol
    private let now: @Sendable () -> Date
    private let text: @MainActor (Meeting, Int) -> AlertText
    /// Plan IDs already handed to the system, with their fire date, so a refresh never re-fires a delivered alert.
    private var scheduled: [String: Date] = [:]

    public init(
        center: any NotificationCenterProtocol,
        now: @escaping @Sendable () -> Date = { Date() },
        text: @escaping @MainActor (Meeting, Int) -> AlertText
    ) {
        self.center = center
        self.now = now
        self.text = text
    }

    public func reconcile(meetings: [Meeting], filter: EventFilter?, rules: AlertRules) async {
        let current = now()
        scheduled = scheduled.filter { $0.value > current.addingTimeInterval(-3600) }

        let plan = AlertPlanner.plan(meetings: meetings, filter: filter, rules: rules, now: current)
        let planIDs = Set(plan.map(\.id))
        let pending = Set(await center.pendingIdentifiers(prefix: AlertPlanner.idPrefix))

        let stale = pending.subtracting(planIDs)
        if !stale.isEmpty { await center.removePending(identifiers: Array(stale)) }

        for alert in plan where !pending.contains(alert.id) && scheduled[alert.id] == nil {
            let content = text(alert.meeting, rules.leadMinutes)
            await center.add(AlertRequest(
                id: alert.id,
                fireDate: alert.fireDate,
                title: content.title,
                body: content.body,
                sound: rules.sound,
                categoryID: alert.meeting.link == nil ? NotificationIDs.snoozeOnlyCategory : NotificationIDs.joinCategory,
                userInfo: AlertPayload.userInfo(for: alert.meeting)
            ))
            scheduled[alert.id] = alert.fireDate
        }
    }

    /// Re-delivers the same reminder after `seconds`, unless the meeting will be over by then.
    public func snooze(userInfo: [String: String], title: String, body: String, sound: Bool, seconds: TimeInterval = 60) async {
        guard let meetingID = userInfo["meetingID"] else { return }
        let fire = now().addingTimeInterval(seconds)
        if let end = userInfo["end"].flatMap(Double.init), fire >= Date(timeIntervalSinceReferenceDate: end) { return }
        await center.add(AlertRequest(
            id: "\(NotificationIDs.snoozePrefix)\(meetingID).\(Int(fire.timeIntervalSince1970))",
            fireDate: fire,
            title: title,
            body: body,
            sound: sound,
            categoryID: userInfo["url"] == nil ? NotificationIDs.snoozeOnlyCategory : NotificationIDs.joinCategory,
            userInfo: userInfo
        ))
    }
}

/// `UNUserNotificationCenter`-backed implementation. Only create it inside the running app:
/// the center asserts when there is no app bundle (for example in a unit-test host).
public final class SystemNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    private var center: UNUserNotificationCenter { .current() }

    public init() {}

    public func authorizationStatus() async -> NotificationAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .authorized
        case .denied: .denied
        default: .notDetermined
        }
    }

    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func registerCategories(joinTitle: String, snoozeTitle: String) async {
        let join = UNNotificationAction(identifier: NotificationIDs.joinAction, title: joinTitle, options: [])
        let snooze = UNNotificationAction(identifier: NotificationIDs.snoozeAction, title: snoozeTitle, options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: NotificationIDs.joinCategory, actions: [join, snooze], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: NotificationIDs.snoozeOnlyCategory, actions: [snooze], intentIdentifiers: [], options: []),
        ])
    }

    public func add(_ request: AlertRequest) async {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.categoryIdentifier = request.categoryID
        content.userInfo = request.userInfo
        content.sound = request.sound ? .default : nil
        content.interruptionLevel = .timeSensitive
        // A time-interval trigger is an absolute moment, so time zone changes cannot shift it.
        let interval = max(1, request.fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
        } catch {
            Log.scheduling.error("Could not schedule notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func pendingIdentifiers(prefix: String) async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
    }

    public func removePending(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
