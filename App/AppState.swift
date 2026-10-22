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
    @ObservationIgnored private var scheduler: MeetingScheduler?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0

    init(settings: SettingsStore, service: CalendarService, launcher: MeetingLauncher, launchAtLogin: LaunchAtLogin) {
        self.settings = settings
        self.service = service
        self.launcher = launcher
        self.launchAtLogin = launchAtLogin
        eventFilter = EventFilter(rules: settings.value.filterRules)
    }

    convenience init() {
        let monitor = ChangeMonitor.live()
        self.init(
            settings: SettingsStore(),
            service: CalendarService(dataSource: EventKitDataSource(), changes: { monitor.changes() }),
            launcher: MeetingLauncher(),
            launchAtLogin: LaunchAtLogin()
        )
    }

    var sections: [DaySection] {
        MeetingList.sections(
            meetings,
            options: settings.value.listOptions,
            filter: eventFilter,
            now: now,
            calendar: .autoupdatingCurrent
        )
    }

    var calendarGroups: [CalendarGroup] {
        CalendarGroup.groups(from: calendars)
    }

    func start() {
        guard updatesTask == nil else { return }
        scheduler = MeetingScheduler { [weak self] snapshot in
            self?.timeline = snapshot
            self?.now = snapshot.now
        }
        settings.onChange = { [weak self] old, new in
            guard let self else { return }
            if old.filterRules != new.filterRules {
                eventFilter = EventFilter(rules: new.filterRules)
                scheduler?.update(meetings: meetings, filter: eventFilter)
            }
            guard old.daysAhead != new.daysAhead || old.disabledCalendarIDs != new.disabledCalendarIDs else { return }
            Task { await self.refresh() }
        }
        let updates = service.updates()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            await requestAccessIfNeeded()
            for await reason in updates {
                Log.calendar.debug("Refreshing after change: \(String(describing: reason), privacy: .public)")
                await refresh()
            }
        }
    }

    func isIgnored(_ meeting: Meeting) -> Bool {
        eventFilter.isPersonal(meeting)
    }

    // MARK: Joining

    func join(_ meeting: Meeting) {
        guard let link = meeting.link else { return }
        requestClosePopover?()
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
        scheduler?.update(meetings: snapshot.meetings, filter: eventFilter)
    }

    private func requestAccessIfNeeded() async {
        await refresh()
        if authorization == .notDetermined {
            await requestAccess()
        }
    }
}
