import Foundation
import NextCallCore
import Observation

/// Single source of truth for the UI. Views read from here and never touch EventKit directly.
@MainActor
@Observable
final class AppState {
    let settings: SettingsStore

    private(set) var authorization: CalendarAuthorization = .notDetermined
    private(set) var calendars: [CalendarRef] = []
    private(set) var meetings: [Meeting] = []
    private(set) var now = Date()

    /// Text shown next to the menu bar icon; `nil` means icon only.
    var menuBarTitle: String?

    @ObservationIgnored private let service: CalendarService
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0

    init(settings: SettingsStore, service: CalendarService) {
        self.settings = settings
        self.service = service
    }

    convenience init() {
        let monitor = ChangeMonitor.live()
        self.init(
            settings: SettingsStore(),
            service: CalendarService(dataSource: EventKitDataSource(), changes: { monitor.changes() })
        )
    }

    var sections: [DaySection] {
        MeetingList.sections(meetings, options: settings.value.listOptions, now: now, calendar: .autoupdatingCurrent)
    }

    var calendarGroups: [CalendarGroup] {
        CalendarGroup.groups(from: calendars)
    }

    func start() {
        guard updatesTask == nil else { return }
        settings.onChange = { [weak self] old, new in
            guard old.daysAhead != new.daysAhead || old.disabledCalendarIDs != new.disabledCalendarIDs else { return }
            Task { await self?.refresh() }
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
    }

    private func requestAccessIfNeeded() async {
        await refresh()
        if authorization == .notDetermined {
            await requestAccess()
        }
    }
}
