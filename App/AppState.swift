import AppKit
import Foundation
import NextCallCore
import Observation

/// Single source of truth for the UI. Views read from here and never touch EventKit directly.
@MainActor
@Observable
final class AppState {
    let settings: SettingsStore
    let launchAtLogin: LaunchAtLogin

    private(set) var authorization: CalendarAuthorization = .notDetermined
    private(set) var notificationAuthorization: NotificationAuthorization = .notDetermined
    private(set) var calendars: [CalendarRef] = []
    private(set) var meetings: [Meeting] = []
    /// Advances once a minute with the scheduler, so dimming, progress and countdowns stay current.
    private(set) var now = Date()
    private(set) var timeline = TimelineSnapshot.empty(now: Date())
    /// Rebuilt only when the rules change, because it compiles one pattern per ignore keyword.
    private(set) var eventFilter: EventFilter

    /// Set by the status item so joining can dismiss the popover.
    @ObservationIgnored var requestClosePopover: (@MainActor () -> Void)?

    @ObservationIgnored private let service: CalendarService
    @ObservationIgnored private let launcher: MeetingLauncher
    @ObservationIgnored private let notificationCenter: any NotificationCenterProtocol
    @ObservationIgnored private let alertPresenter = AlertPresenter()
    @ObservationIgnored private var alertTracker = FullScreenAlertTracker()
    @ObservationIgnored private var notifications: NotificationScheduler?
    @ObservationIgnored private var scheduler: MeetingScheduler?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0

    init(
        settings: SettingsStore,
        service: CalendarService,
        launcher: MeetingLauncher,
        launchAtLogin: LaunchAtLogin,
        notificationCenter: any NotificationCenterProtocol
    ) {
        self.settings = settings
        self.service = service
        self.launcher = launcher
        self.launchAtLogin = launchAtLogin
        self.notificationCenter = notificationCenter
        eventFilter = EventFilter(rules: settings.value.filterRules)
    }

    convenience init() {
        let monitor = ChangeMonitor.live()
        self.init(
            settings: SettingsStore(),
            service: CalendarService(dataSource: EventKitDataSource(), changes: { monitor.changes() }),
            launcher: MeetingLauncher(),
            launchAtLogin: LaunchAtLogin(),
            notificationCenter: SystemNotificationCenter()
        )
    }

    /// Meetings the user has not hidden: the input of the list, the timeline, notifications and alerts.
    var visibleMeetings: [Meeting] {
        let hidden = settings.value.hiddenMeetings
        return hidden.isEmpty ? meetings : meetings.filter { hidden[$0.id] == nil }
    }

    var sections: [DaySection] {
        MeetingList.sections(
            visibleMeetings,
            options: settings.value.listOptions,
            filter: eventFilter,
            now: now,
            calendar: .autoupdatingCurrent
        )
    }

    var calendarGroups: [CalendarGroup] {
        CalendarGroup.groups(from: calendars)
    }

    // MARK: Lifecycle

    func start() {
        guard updatesTask == nil else { return }
        scheduler = MeetingScheduler { [weak self] snapshot in
            self?.handle(snapshot)
        }
        notifications = NotificationScheduler(center: notificationCenter) { meeting, lead in
            Self.notificationText(for: meeting, leadMinutes: lead)
        }
        settings.onChange = { [weak self] old, new in
            self?.settingsDidChange(from: old, to: new)
        }
        let updates = service.updates()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            await notificationCenter.registerCategories(
                joinTitle: String(localized: "Join"),
                snoozeTitle: String(localized: "Snooze 1 min")
            )
            await refreshNotificationAuthorization()
            await requestAccessIfNeeded()
            for await reason in updates {
                Log.calendar.debug("Refreshing after change: \(String(describing: reason), privacy: .public)")
                await refresh()
            }
        }
    }

    private func settingsDidChange(from old: AppSettings, to new: AppSettings) {
        if old.filterRules != new.filterRules {
            eventFilter = EventFilter(rules: new.filterRules)
        }
        if old.filterRules != new.filterRules || old.hiddenMeetings != new.hiddenMeetings {
            scheduler?.update(meetings: visibleMeetings, filter: eventFilter)
        }
        if old.filterRules != new.filterRules || old.hiddenMeetings != new.hiddenMeetings || old.alertRules != new.alertRules {
            Task { await reconcileNotifications() }
        }
        if old.alertRules.enabled != new.alertRules.enabled, new.alertRules.enabled {
            Task { await requestNotificationAccessIfNeeded() }
        }
        if old.daysAhead != new.daysAhead || old.disabledCalendarIDs != new.disabledCalendarIDs {
            Task { await refresh() }
        }
    }

    /// Called on every timeline tick (once a minute, and on new input).
    private func handle(_ snapshot: TimelineSnapshot) {
        timeline = snapshot
        now = snapshot.now
        guard settings.value.fullScreenAlertEnabled else { return }
        let due = alertTracker.due(
            snapshot: snapshot,
            filter: eventFilter,
            onlyWithLinks: settings.value.alertsOnlyWithLinks
        )
        // If several start together, show the one that starts last; the rest are in the popover.
        if let meeting = due.last { showFullScreenAlert(for: meeting) }
    }

    func isIgnored(_ meeting: Meeting) -> Bool {
        eventFilter.isPersonal(meeting)
    }

    // MARK: Joining

    func join(_ meeting: Meeting) {
        guard let link = meeting.link else { return }
        join(link)
    }

    private func join(_ link: MeetingLink) {
        requestClosePopover?()
        alertPresenter.dismiss()
        let preferences = settings.value.launchPreferences
        Task {
            let result = await launcher.join(link, preferences: preferences)
            Log.launching.info("Joined \(link.provider.rawValue, privacy: .public): \(String(describing: result), privacy: .public)")
        }
    }

    /// Joins the meeting the header button would join. Returns false when there is none.
    @discardableResult
    func joinNext() -> Bool {
        guard let target = timeline.joinTarget else { return false }
        join(target)
        return true
    }

    // MARK: Alerts and notifications

    func showFullScreenAlert(for meeting: Meeting) {
        alertPresenter.show(meeting) { [weak self] in self?.join(meeting) }
    }

    func dismissFullScreenAlert() {
        alertPresenter.dismiss()
    }

    func handleNotification(_ response: NotificationResponse) {
        switch response.action {
        case NotificationIDs.snoozeAction:
            let sound = settings.value.notificationSound
            Task {
                await notifications?.snooze(userInfo: response.userInfo, title: response.title, body: response.body, sound: sound)
            }
        case NotificationIDs.joinAction:
            joinFromNotification(response)
        default:
            // Tapping the banner itself joins when the meeting has a link.
            if response.action == "com.apple.UNNotificationDefaultActionIdentifier" { joinFromNotification(response) }
        }
    }

    private func joinFromNotification(_ response: NotificationResponse) {
        guard let link = AlertPayload.link(from: response.userInfo) else { return }
        join(link)
    }

    func requestNotificationAccess() async {
        _ = await notificationCenter.requestAuthorization()
        await refreshNotificationAuthorization()
        await reconcileNotifications()
    }

    func refreshNotificationAuthorization() async {
        notificationAuthorization = await notificationCenter.authorizationStatus()
    }

    private func requestNotificationAccessIfNeeded() async {
        await refreshNotificationAuthorization()
        if notificationAuthorization == .notDetermined { await requestNotificationAccess() }
    }

    private func reconcileNotifications() async {
        await notifications?.reconcile(meetings: visibleMeetings, filter: eventFilter, rules: settings.value.alertRules)
    }

    private static func notificationText(for meeting: Meeting, leadMinutes: Int) -> AlertText {
        var body = leadMinutes == 0
            ? String(localized: "Starting now")
            : String(localized: "Starts in \(StatusText.duration(minutes: leadMinutes))")
        if let link = meeting.link { body += " · " + link.provider.displayName }
        return AlertText(title: StatusText.displayTitle(meeting), body: body)
    }

    // MARK: Event actions (FR-14, FR-16)

    func copyLink(_ meeting: Meeting) {
        guard let link = meeting.link else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link.url.absoluteString, forType: .string)
    }

    func openInCalendar(_ meeting: Meeting) {
        requestClosePopover?()
        if let url = MeetingActions.calendarURL(for: meeting), NSWorkspace.shared.open(url) { return }
        // The deep link was not handled: at least bring Calendar forward.
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func emailAttendees(_ meeting: Meeting) {
        guard let url = MeetingActions.mailtoURL(for: meeting) else { return }
        requestClosePopover?()
        NSWorkspace.shared.open(url)
    }

    /// Hides this one occurrence. Entries are kept a week past the meeting's end, then forgotten.
    func hide(_ meeting: Meeting) {
        let cutoff = Date().addingTimeInterval(-7 * 86_400).timeIntervalSinceReferenceDate
        settings.update { settings in
            settings.hiddenMeetings[meeting.id] = meeting.end.timeIntervalSinceReferenceDate
            settings.hiddenMeetings = settings.hiddenMeetings.filter { $0.value > cutoff }
        }
    }

    func unhideAll() {
        settings.update { $0.hiddenMeetings = [:] }
    }

    func canIgnoreTitle(_ meeting: Meeting) -> Bool {
        let title = meeting.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && !settings.value.ignoreKeywords.contains { $0.caseInsensitiveCompare(title) == .orderedSame }
    }

    func ignoreEvents(titled meeting: Meeting) {
        let title = meeting.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canIgnoreTitle(meeting) else { return }
        settings.update { $0.ignoreKeywords.append(title) }
    }

    // MARK: Calendar

    func requestAccess() async {
        authorization = await service.requestAccess()
        await refresh()
    }

    func refresh() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        let current = settings.value
        let snapshot = await service.snapshot(days: current.daysAhead, excludingCalendarIDs: current.disabledCalendarIDs)
        // A newer refresh (for example after a settings change) supersedes this one.
        guard generation == refreshGeneration else { return }
        authorization = snapshot.authorization
        calendars = snapshot.calendars
        meetings = snapshot.meetings
        now = snapshot.fetchedAt
        scheduler?.update(meetings: visibleMeetings, filter: eventFilter)
        await reconcileNotifications()
    }

    private func requestAccessIfNeeded() async {
        await refresh()
        if authorization == .notDetermined {
            await requestAccess()
        }
    }
}
