import Foundation
import Testing
@testable import NextCallCore

private let link = MeetingLink(
    provider: .zoom,
    url: URL(string: "https://zoom.us/j/123456789?pwd=abc")!,
    nativeURL: URL(string: "zoommtg://zoom.us/join?confno=123456789&pwd=abc")
)

private func meeting(
    _ id: String,
    title: String = "Sync",
    start: Date,
    minutes: Int = 30,
    withLink: Bool = true,
    status: ParticipantStatus = .accepted,
    allDay: Bool = false,
    attendees: Int = 3
) -> Meeting {
    Meeting(
        raw: makeEvent(id, title: title, start: start, minutes: minutes, allDay: allDay, status: status, attendees: attendees),
        link: withLink ? link : nil
    )
}

@Suite struct AlertPlannerTests {
    private let now = makeDate(2026, 3, 10, 10, 0)
    private let filter = EventFilter()

    private func plan(_ meetings: [Meeting], rules: AlertRules = AlertRules(), at time: Date? = nil) -> [PlannedAlert] {
        AlertPlanner.plan(meetings: meetings, filter: filter, rules: rules, now: time ?? now)
    }

    @Test func firesLeadMinutesBeforeTheStart() {
        let m = meeting("a", start: makeDate(2026, 3, 10, 10, 30))
        let alerts = plan([m], rules: AlertRules(leadMinutes: 5))
        #expect(alerts.count == 1)
        #expect(alerts[0].fireDate == makeDate(2026, 3, 10, 10, 25))
        #expect(!alerts[0].isLate)
    }

    @Test func zeroLeadFiresAtTheStart() {
        let m = meeting("a", start: makeDate(2026, 3, 10, 10, 30))
        #expect(plan([m], rules: AlertRules(leadMinutes: 0))[0].fireDate == m.start)
    }

    @Test func disabledRulesPlanNothing() {
        let m = meeting("a", start: makeDate(2026, 3, 10, 10, 30))
        #expect(plan([m], rules: AlertRules(enabled: false)).isEmpty)
    }

    @Test func skipsStartedAndFinishedMeetings() {
        let started = meeting("s", start: makeDate(2026, 3, 10, 9, 59))
        let startingNow = meeting("n", start: now)
        let over = meeting("o", start: makeDate(2026, 3, 10, 8, 0))
        #expect(plan([started, startingNow, over]).isEmpty)
    }

    @Test func lateAlertFiresAlmostImmediatelyAndIsFlagged() {
        let m = meeting("a", start: makeDate(2026, 3, 10, 10, 0).addingTimeInterval(30)) // 30 s away, lead 1 min
        let alert = plan([m])[0]
        #expect(alert.isLate)
        #expect(alert.fireDate == now.addingTimeInterval(1))
    }

    @Test func neverAlertsForAllDayDeclinedOrPersonalEvents() {
        let allDay = meeting("ad", start: makeDate(2026, 3, 10, 12), minutes: 1440, allDay: true)
        let declined = meeting("d", start: makeDate(2026, 3, 10, 12), status: .declined)
        let lunch = meeting("l", title: "Lunch", start: makeDate(2026, 3, 10, 12), withLink: false)
        let solo = meeting("s", title: "Writing", start: makeDate(2026, 3, 10, 12), withLink: false, attendees: 0)
        #expect(plan([allDay, declined, lunch, solo]).isEmpty)
    }

    @Test func personalBlockWithALinkStillAlerts() {
        let m = meeting("a", title: "Lunch", start: makeDate(2026, 3, 10, 12), withLink: true, attendees: 0)
        #expect(plan([m]).count == 1)
    }

    @Test func onlyWithLinksSkipsMeetingsWithoutOne() {
        let noLink = meeting("n", title: "Review", start: makeDate(2026, 3, 10, 12), withLink: false)
        let linked = meeting("l", start: makeDate(2026, 3, 10, 13))
        #expect(plan([noLink, linked], rules: AlertRules(onlyWithLinks: true)).map(\.meeting.id) == ["l"])
        #expect(plan([noLink, linked], rules: AlertRules(onlyWithLinks: false)).count == 2)
    }

    @Test func plansOnlyWithinTheHorizonAndCapsTheCount() {
        let far = meeting("far", start: now.addingTimeInterval(AlertPlanner.horizon + 60))
        let near = (0..<60).map { meeting("m\($0)", start: now.addingTimeInterval(Double(120 + $0 * 60))) }
        let alerts = plan([far] + near)
        #expect(alerts.count == AlertPlanner.maxAlerts)
        #expect(!alerts.contains { $0.meeting.id == "far" })
        #expect(alerts.first?.meeting.id == "m0") // soonest first
    }

    @Test func idChangesWithTheMeetingOccurrenceAndTheRules() {
        // Real meeting IDs end in the occurrence start (see `Meeting.id`), so a moved meeting is a new ID.
        let a = meeting("event|100", start: makeDate(2026, 3, 10, 12))
        let moved = meeting("event|200", start: makeDate(2026, 3, 10, 13))
        #expect(plan([a])[0].id != plan([moved])[0].id)
        #expect(plan([a], rules: AlertRules(leadMinutes: 1))[0].id != plan([a], rules: AlertRules(leadMinutes: 2))[0].id)
        #expect(plan([a], rules: AlertRules(sound: true))[0].id != plan([a], rules: AlertRules(sound: false))[0].id)
        #expect(plan([a])[0].id.hasPrefix(AlertPlanner.idPrefix))
    }
}

@Suite struct FullScreenAlertTrackerTests {
    private let filter = EventFilter()

    private func snapshot(_ meetings: [Meeting], at now: Date) -> TimelineSnapshot {
        MeetingTimeline.snapshot(meetings: meetings, filter: filter, now: now)
    }

    @Test func dueOnceWhenTheMeetingStarts() {
        var tracker = FullScreenAlertTracker()
        let m = meeting("a", start: makeDate(2026, 3, 10, 10, 0))
        #expect(tracker.due(snapshot: snapshot([m], at: makeDate(2026, 3, 10, 9, 59)), filter: filter, onlyWithLinks: false).isEmpty)
        #expect(tracker.due(snapshot: snapshot([m], at: makeDate(2026, 3, 10, 10, 0)), filter: filter, onlyWithLinks: false) == [m])
        #expect(tracker.due(snapshot: snapshot([m], at: makeDate(2026, 3, 10, 10, 1)), filter: filter, onlyWithLinks: false).isEmpty)
    }

    @Test func aMissedTickStillAlertsWithinTheGraceWindow() {
        var tracker = FullScreenAlertTracker()
        let m = meeting("a", start: makeDate(2026, 3, 10, 10, 0))
        #expect(tracker.due(snapshot: snapshot([m], at: makeDate(2026, 3, 10, 10, 2)), filter: filter, onlyWithLinks: false) == [m])
    }

    @Test func aMeetingThatStartedLongAgoIsNotAlerted() {
        var tracker = FullScreenAlertTracker()
        let m = meeting("a", start: makeDate(2026, 3, 10, 10, 0))
        #expect(tracker.due(snapshot: snapshot([m], at: makeDate(2026, 3, 10, 10, 3)), filter: filter, onlyWithLinks: false).isEmpty)
    }

    @Test func respectsOnlyWithLinks() {
        var tracker = FullScreenAlertTracker()
        let m = meeting("a", title: "Review", start: makeDate(2026, 3, 10, 10, 0), withLink: false)
        let s = snapshot([m], at: makeDate(2026, 3, 10, 10, 0))
        #expect(tracker.due(snapshot: s, filter: filter, onlyWithLinks: true).isEmpty)
        #expect(tracker.due(snapshot: s, filter: filter, onlyWithLinks: false) == [m])
    }

    @Test func overlappingStartsAreBothReported() {
        var tracker = FullScreenAlertTracker()
        let a = meeting("a", start: makeDate(2026, 3, 10, 10, 0))
        let b = meeting("b", start: makeDate(2026, 3, 10, 10, 0))
        #expect(tracker.due(snapshot: snapshot([a, b], at: makeDate(2026, 3, 10, 10, 0)), filter: filter, onlyWithLinks: false).count == 2)
    }

    @Test func personalBlocksAndDeclinedNeverAlert() {
        var tracker = FullScreenAlertTracker()
        let lunch = meeting("l", title: "Lunch", start: makeDate(2026, 3, 10, 10, 0), withLink: false)
        let declined = meeting("d", start: makeDate(2026, 3, 10, 10, 0), status: .declined)
        #expect(tracker.due(snapshot: snapshot([lunch, declined], at: makeDate(2026, 3, 10, 10, 0)), filter: filter, onlyWithLinks: false).isEmpty)
    }
}

actor FakeNotificationCenter: NotificationCenterProtocol {
    var status: NotificationAuthorization = .authorized
    private(set) var added: [AlertRequest] = []
    private(set) var pending: [String: AlertRequest] = [:]
    private(set) var removed: [String] = []
    private(set) var categoriesRegistered = false

    func authorizationStatus() async -> NotificationAuthorization { status }
    func requestAuthorization() async -> Bool { status = .authorized; return true }
    func registerCategories(joinTitle: String, snoozeTitle: String) async { categoriesRegistered = true }

    func add(_ request: AlertRequest) async {
        added.append(request)
        pending[request.id] = request
    }

    func pendingIdentifiers(prefix: String) async -> [String] {
        pending.keys.filter { $0.hasPrefix(prefix) }
    }

    func removePending(identifiers: [String]) async {
        removed.append(contentsOf: identifiers)
        for id in identifiers { pending[id] = nil }
    }

    /// Simulates the system delivering (and thereby consuming) a pending request.
    func deliver(_ id: String) { pending[id] = nil }
}

@MainActor
@Suite struct NotificationSchedulerTests {
    private let filter = EventFilter()

    final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func make(_ center: FakeNotificationCenter, clock: Clock) -> NotificationScheduler {
        NotificationScheduler(center: center, now: { clock.now }) { meeting, lead in
            AlertText(title: meeting.title, body: "in \(lead)")
        }
    }

    @Test func schedulesOneRequestPerEligibleMeeting() async {
        let center = FakeNotificationCenter()
        let clock = Clock(makeDate(2026, 3, 10, 10, 0))
        let scheduler = make(center, clock: clock)
        let a = meeting("a", title: "Alpha", start: makeDate(2026, 3, 10, 11, 0))
        let b = meeting("b", title: "Beta", start: makeDate(2026, 3, 10, 12, 0), withLink: false)
        await scheduler.reconcile(meetings: [a, b], filter: filter, rules: AlertRules(leadMinutes: 2))
        let added = await center.added
        #expect(added.map(\.title) == ["Alpha", "Beta"])
        #expect(added[0].fireDate == makeDate(2026, 3, 10, 10, 58))
        #expect(added[0].categoryID == NotificationIDs.joinCategory)
        #expect(added[1].categoryID == NotificationIDs.snoozeOnlyCategory)
        #expect(added[0].body == "in 2")
        #expect(AlertPayload.link(from: added[0].userInfo) == link)
        #expect(AlertPayload.link(from: added[1].userInfo) == nil)
    }

    @Test func reconcilingTwiceDoesNotDuplicate() async {
        let center = FakeNotificationCenter()
        let scheduler = make(center, clock: Clock(makeDate(2026, 3, 10, 10, 0)))
        let a = meeting("a", start: makeDate(2026, 3, 10, 11, 0))
        await scheduler.reconcile(meetings: [a], filter: filter, rules: AlertRules())
        await scheduler.reconcile(meetings: [a], filter: filter, rules: AlertRules())
        #expect(await center.added.count == 1)
    }

    @Test func movedOrRemovedMeetingsReplaceTheirOldRequest() async {
        let center = FakeNotificationCenter()
        let scheduler = make(center, clock: Clock(makeDate(2026, 3, 10, 10, 0)))
        let original = meeting("a", start: makeDate(2026, 3, 10, 11, 0))
        await scheduler.reconcile(meetings: [original], filter: filter, rules: AlertRules())
        let oldID = await center.added[0].id

        let renamed = Meeting(raw: makeEvent("a2", title: "Sync", start: makeDate(2026, 3, 10, 11, 30)), link: link)
        await scheduler.reconcile(meetings: [renamed], filter: filter, rules: AlertRules())
        #expect(await center.removed == [oldID])
        #expect(await center.pending.count == 1)

        await scheduler.reconcile(meetings: [], filter: filter, rules: AlertRules())
        #expect(await center.pending.isEmpty)
    }

    @Test func disablingNotificationsClearsEverythingPending() async {
        let center = FakeNotificationCenter()
        let scheduler = make(center, clock: Clock(makeDate(2026, 3, 10, 10, 0)))
        let a = meeting("a", start: makeDate(2026, 3, 10, 11, 0))
        await scheduler.reconcile(meetings: [a], filter: filter, rules: AlertRules())
        await scheduler.reconcile(meetings: [a], filter: filter, rules: AlertRules(enabled: false))
        #expect(await center.pending.isEmpty)
    }

    @Test func changingTheLeadTimeReschedules() async {
        let center = FakeNotificationCenter()
        let scheduler = make(center, clock: Clock(makeDate(2026, 3, 10, 10, 0)))
        let a = meeting("a", start: makeDate(2026, 3, 10, 11, 0))
        await scheduler.reconcile(meetings: [a], filter: filter, rules: AlertRules(leadMinutes: 1))
        await scheduler.reconcile(meetings: [a], filter: filter, rules: AlertRules(leadMinutes: 10))
        let pending = await center.pending.values
        #expect(pending.count == 1)
        #expect(pending.first?.fireDate == makeDate(2026, 3, 10, 10, 50))
    }

    @Test func aDeliveredAlertIsNotFiredAgainOnRefresh() async {
        let center = FakeNotificationCenter()
        let clock = Clock(makeDate(2026, 3, 10, 10, 0))
        let scheduler = make(center, clock: clock)
        let a = meeting("a", start: makeDate(2026, 3, 10, 10, 30))
        await scheduler.reconcile(meetings: [a], filter: filter, rules: AlertRules())
        let id = await center.added[0].id
        await center.deliver(id)
        clock.now = makeDate(2026, 3, 10, 10, 29, calendar: TestCalendars.utc).addingTimeInterval(30)
        await scheduler.reconcile(meetings: [a], filter: filter, rules: AlertRules())
        #expect(await center.added.count == 1)
    }

    @Test func lateAlertIsScheduledOnceForImmediateDelivery() async {
        let center = FakeNotificationCenter()
        let clock = Clock(makeDate(2026, 3, 10, 10, 0))
        let scheduler = make(center, clock: clock)
        let a = meeting("a", start: clock.now.addingTimeInterval(30))
        await scheduler.reconcile(meetings: [a], filter: filter, rules: AlertRules())
        #expect(await center.added.first?.fireDate == clock.now.addingTimeInterval(1))
        await scheduler.reconcile(meetings: [a], filter: filter, rules: AlertRules())
        #expect(await center.added.count == 1)
    }

    @Test func ignoredMeetingsAreNotScheduled() async {
        let center = FakeNotificationCenter()
        let scheduler = make(center, clock: Clock(makeDate(2026, 3, 10, 10, 0)))
        let lunch = meeting("l", title: "Lunch", start: makeDate(2026, 3, 10, 12), withLink: false)
        await scheduler.reconcile(meetings: [lunch], filter: filter, rules: AlertRules())
        #expect(await center.added.isEmpty)
    }

    // MARK: Snooze

    @Test func snoozeReschedulesTheSameReminderInOneMinute() async {
        let center = FakeNotificationCenter()
        let clock = Clock(makeDate(2026, 3, 10, 10, 29))
        let scheduler = make(center, clock: clock)
        let a = meeting("a", start: makeDate(2026, 3, 10, 10, 30), minutes: 30)
        await scheduler.snooze(userInfo: AlertPayload.userInfo(for: a), title: "Sync", body: "in 1", sound: true)
        let request = await center.added.first
        #expect(request?.fireDate == makeDate(2026, 3, 10, 10, 30))
        #expect(request?.id.hasPrefix(NotificationIDs.snoozePrefix) == true)
        #expect(request?.categoryID == NotificationIDs.joinCategory)
        #expect(request?.userInfo["url"] == link.url.absoluteString)
    }

    @Test func snoozeIsDroppedWhenTheMeetingWillBeOver() async {
        let center = FakeNotificationCenter()
        let clock = Clock(makeDate(2026, 3, 10, 10, 59).addingTimeInterval(30))
        let scheduler = make(center, clock: clock)
        let a = meeting("a", start: makeDate(2026, 3, 10, 10, 30), minutes: 30)
        await scheduler.snooze(userInfo: AlertPayload.userInfo(for: a), title: "Sync", body: "", sound: true)
        #expect(await center.added.isEmpty)
    }

    @Test func snoozeWithoutAMeetingIDDoesNothing() async {
        let center = FakeNotificationCenter()
        let scheduler = make(center, clock: Clock(makeDate(2026, 3, 10, 10, 0)))
        await scheduler.snooze(userInfo: [:], title: "x", body: "y", sound: true)
        #expect(await center.added.isEmpty)
    }

    @Test func snoozedRemindersSurviveAReconcile() async {
        let center = FakeNotificationCenter()
        let clock = Clock(makeDate(2026, 3, 10, 10, 0))
        let scheduler = make(center, clock: clock)
        let a = meeting("a", start: makeDate(2026, 3, 10, 10, 30))
        await scheduler.snooze(userInfo: AlertPayload.userInfo(for: a), title: "Sync", body: "", sound: true)
        await scheduler.reconcile(meetings: [], filter: filter, rules: AlertRules())
        #expect(await center.removed.isEmpty)
    }

    @Test func payloadRoundTripsALink() {
        let m = meeting("a", start: makeDate(2026, 3, 10, 10, 30))
        #expect(AlertPayload.link(from: AlertPayload.userInfo(for: m)) == link)
        #expect(AlertPayload.link(from: ["provider": "nope", "url": "https://x.example"]) == nil)
    }
}

@MainActor
@Suite struct BrowserCatalogTests {
    @Test func listsOnlyInstalledKnownBrowsers() {
        let workspace = FakeWorkspace()
        workspace.installedBundles["com.apple.Safari"] = URL(fileURLWithPath: "/Applications/Safari.app")
        workspace.installedBundles["org.mozilla.firefox"] = URL(fileURLWithPath: "/Applications/Firefox.app")
        workspace.installedBundles["com.example.Unknown"] = URL(fileURLWithPath: "/Applications/Other.app")
        #expect(BrowserCatalog.installed(using: workspace).map(\.name) == ["Safari", "Firefox"])
    }

    @Test func knownBrowsersCoverThePRDList() {
        let names = Set(BrowserCatalog.known.map(\.name))
        #expect(names.isSuperset(of: ["Safari", "Google Chrome", "Arc", "Microsoft Edge", "Firefox"]))
    }

    @Test func nativeSchemeLookupAndInstallProbe() {
        #expect(ProviderRegistry.nativeScheme(for: .zoom) == .zoom)
        #expect(ProviderRegistry.nativeScheme(for: .googleMeet) == .none)
        #expect(ProviderRegistry.nativeScheme(for: .discord) == .discord)

        let workspace = FakeWorkspace()
        workspace.handledSchemes = ["zoommtg"]
        #expect(ProviderRegistry.isNativeAppInstalled(for: .zoom, using: workspace))
        #expect(!ProviderRegistry.isNativeAppInstalled(for: .teams, using: workspace))
        #expect(!ProviderRegistry.isNativeAppInstalled(for: .googleMeet, using: workspace))
    }

    @Test func everyNativeSchemeHasAProbeURL() {
        for scheme in [NativeScheme.zoom, .teams, .webex, .slack, .discord, .jitsi] {
            #expect(scheme.probeURL != nil)
        }
        #expect(NativeScheme.none.probeURL == nil)
    }
}

@Suite struct MeetingActionsTests {
    private func meeting(title: String = "Design review", emails: [String] = [], id: String = "ABC-123|776000000") -> Meeting {
        Meeting(raw: RawEvent(
            id: id, title: title, start: makeDate(2026, 3, 10, 10), end: makeDate(2026, 3, 10, 11),
            calendar: makeCalendarRef(), attendeeEmails: emails
        ))
    }

    @Test func mailtoListsAllOtherAttendeesWithTheTitleAsSubject() {
        let url = MeetingActions.mailtoURL(for: meeting(emails: ["a@example.com", "b@example.com"]))
        #expect(url?.scheme == "mailto")
        #expect(url?.absoluteString == "mailto:a@example.com,b@example.com?subject=Design%20review")
    }

    @Test func mailtoEncodesSpecialCharactersInTheSubject() {
        let url = MeetingActions.mailtoURL(for: meeting(title: "Q&A: 50% off?", emails: ["a@example.com"]))
        let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        #expect(components?.queryItems?.first?.value == "Q&A: 50% off?")
        #expect(url?.absoluteString.contains("Q&A") == false)
    }

    @Test func mailtoNeedsAttendees() {
        #expect(MeetingActions.mailtoURL(for: meeting()) == nil)
    }

    @Test func mailtoOmitsAnEmptySubject() {
        #expect(MeetingActions.mailtoURL(for: meeting(title: "", emails: ["a@example.com"]))?.absoluteString == "mailto:a@example.com")
    }

    @Test func calendarURLUsesTheEventIdentifierWithoutTheOccurrence() {
        #expect(meeting().eventIdentifier == "ABC-123")
        #expect(MeetingActions.calendarURL(for: meeting())?.absoluteString == "ical://ekevent/ABC-123?method=show&options=more")
    }

    @Test func identifiersWithoutASuffixAreUsedAsIs() {
        #expect(meeting(id: "plain").eventIdentifier == "plain")
    }
}

@MainActor
@Suite struct AlertSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "NextCallTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsMatchTheSpec() {
        let s = AppSettings()
        #expect(s.notificationsEnabled)
        #expect(s.notificationLeadMinutes == 1)
        #expect(s.notificationSound)
        #expect(!s.alertsOnlyWithLinks)
        #expect(!s.fullScreenAlertEnabled)
        #expect(s.hiddenMeetings.isEmpty)
        #expect(s.alertRules == AlertRules(enabled: true, leadMinutes: 1, sound: true, onlyWithLinks: false))
    }

    @Test func leadMinutesAreClamped() {
        let store = SettingsStore(defaults: makeDefaults())
        store.update { $0.notificationLeadMinutes = 99 }
        #expect(store.value.notificationLeadMinutes == 30)
        store.update { $0.notificationLeadMinutes = -4 }
        #expect(store.value.notificationLeadMinutes == 0)
    }

    @Test func alertFieldsPersistAndOldBlobsStillLoad() {
        let defaults = makeDefaults()
        SettingsStore(defaults: defaults).update {
            $0.notificationLeadMinutes = 5
            $0.fullScreenAlertEnabled = true
            $0.hiddenMeetings = ["a|1": 100]
            $0.alertsOnlyWithLinks = true
        }
        let reloaded = SettingsStore(defaults: defaults).value
        #expect(reloaded.notificationLeadMinutes == 5)
        #expect(reloaded.fullScreenAlertEnabled)
        #expect(reloaded.hiddenMeetings == ["a|1": 100])
        #expect(reloaded.alertRules.onlyWithLinks)

        defaults.set(Data(#"{"daysAhead": 3}"#.utf8), forKey: SettingsStore.key)
        #expect(SettingsStore(defaults: defaults).value.notificationLeadMinutes == 1)
    }
}
