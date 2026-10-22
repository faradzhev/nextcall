import Foundation
import Testing
@testable import NextCallCore

private let zoomLink = MeetingLink(provider: .zoom, url: URL(string: "https://zoom.us/j/123456789")!, nativeURL: nil)

private func timed(
    _ id: String,
    title: String = "Sync",
    start: Date,
    minutes: Int = 30,
    link: Bool = true,
    status: ParticipantStatus = .accepted,
    allDay: Bool = false,
    attendees: Int = 3
) -> Meeting {
    Meeting(
        raw: makeEvent(id, title: title, start: start, minutes: minutes, allDay: allDay, status: status, attendees: attendees),
        link: link ? zoomLink : nil
    )
}

@Suite struct MeetingTimelineTests {
    private let now = makeDate(2026, 3, 10, 10, 0)
    private let filter = EventFilter()

    private func snapshot(_ meetings: [Meeting], at time: Date? = nil, filter: EventFilter? = EventFilter()) -> TimelineSnapshot {
        MeetingTimeline.snapshot(meetings: meetings, filter: filter, now: time ?? now)
    }

    // MARK: Status

    @Test func nothingScheduledIsIdle() {
        let s = snapshot([])
        #expect(s.status == .idle)
        #expect(s.joinTarget == nil)
        #expect(s.next == nil)
    }

    @Test func upcomingMeetingShowsCountdown() {
        let m = timed("a", start: makeDate(2026, 3, 10, 10, 12))
        #expect(snapshot([m]).status == .upcoming(m, secondsUntilStart: 12 * 60))
    }

    @Test func startingExactlyNowIsOngoing() {
        let m = timed("a", start: now)
        let s = snapshot([m])
        #expect(s.status == .ongoing(m))
        #expect(s.ongoing == [m])
        #expect(s.upcoming.isEmpty)
    }

    @Test func endingExactlyNowIsOver() {
        let m = timed("a", start: makeDate(2026, 3, 10, 9, 30), minutes: 30)
        #expect(snapshot([m]).status == .idle)
    }

    @Test func meetingBeyondTheHorizonIsIdle() {
        let m = timed("a", start: makeDate(2026, 3, 10, 18, 1)) // 8h01m away
        let s = snapshot([m])
        #expect(s.status == .idle)
        #expect(s.next == m)
        #expect(s.joinTarget == nil)
    }

    @Test func meetingAtTheHorizonEdgeIsShown() {
        let m = timed("a", start: makeDate(2026, 3, 10, 18, 0))
        #expect(snapshot([m]).status == .upcoming(m, secondsUntilStart: 8 * 3600))
    }

    // MARK: Exclusions

    @Test func allDayEventsNeverDriveTheStatus() {
        let m = timed("a", start: makeDate(2026, 3, 10), minutes: 1440, allDay: true)
        let s = snapshot([m])
        #expect(s.status == .idle)
        #expect(s.ongoing.isEmpty)
        #expect(s.joinTarget == nil)
    }

    @Test func declinedMeetingsAreSkipped() {
        let declined = timed("d", start: makeDate(2026, 3, 10, 10, 5), status: .declined)
        let later = timed("l", start: makeDate(2026, 3, 10, 11, 0))
        let s = snapshot([declined, later])
        #expect(s.next == later)
        #expect(s.joinTarget == later)
    }

    @Test func tentativeAndPendingMeetingsCount() {
        let tentative = timed("t", start: makeDate(2026, 3, 10, 10, 20), status: .tentative)
        let pending = timed("p", start: makeDate(2026, 3, 10, 10, 40), status: .pending)
        #expect(snapshot([tentative, pending]).upcoming.count == 2)
    }

    @Test func personalBlocksAreSkipped() {
        let lunch = timed("lunch", title: "Lunch", start: makeDate(2026, 3, 10, 10, 5), link: false)
        let solo = timed("solo", title: "Writing", start: makeDate(2026, 3, 10, 10, 6), link: false, attendees: 0)
        let real = timed("real", title: "Review", start: makeDate(2026, 3, 10, 10, 30), link: false)
        let s = snapshot([lunch, solo, real])
        #expect(s.upcoming == [real])
    }

    @Test func personalBlockWithLinkStillCounts() {
        let m = timed("a", title: "Lunch", start: makeDate(2026, 3, 10, 10, 5), link: true, attendees: 0)
        #expect(snapshot([m]).next == m)
    }

    @Test func withoutAFilterNothingIsPersonal() {
        let m = timed("a", title: "Lunch", start: makeDate(2026, 3, 10, 10, 5), link: false, attendees: 0)
        #expect(snapshot([m], filter: nil).next == m)
    }

    // MARK: Overlap and join target

    private var longMeeting: Meeting { timed("A", start: makeDate(2026, 3, 10, 10, 0), minutes: 120) }
    private var shortMeeting: Meeting { timed("B", start: makeDate(2026, 3, 10, 11, 0), minutes: 30) }

    @Test func overlappingOngoingMeetingsPreferTheLatestStarted() {
        let s = snapshot([longMeeting, shortMeeting], at: makeDate(2026, 3, 10, 11, 10))
        #expect(s.ongoing.map(\.id) == ["A", "B"])
        #expect(s.status == .ongoing(shortMeeting))
        #expect(s.joinTarget == shortMeeting)
    }

    @Test func staysOnTheRunningMeetingUntilTheNextIsImminent() {
        let s = snapshot([longMeeting, shortMeeting], at: makeDate(2026, 3, 10, 10, 30))
        #expect(s.status == .ongoing(longMeeting))
        #expect(s.joinTarget == longMeeting)
    }

    @Test func imminentMeetingTakesOverFromARunningOne() {
        let s = snapshot([longMeeting, shortMeeting], at: makeDate(2026, 3, 10, 10, 56))
        #expect(s.status == .upcoming(shortMeeting, secondsUntilStart: 4 * 60))
        #expect(s.joinTarget == shortMeeting)
    }

    @Test func imminentWindowBoundaryIsInclusive() {
        let m = timed("a", start: makeDate(2026, 3, 10, 10, 5))
        let s = snapshot([longMeeting, m], at: makeDate(2026, 3, 10, 10, 0))
        #expect(s.status == .upcoming(m, secondsUntilStart: 300))
    }

    @Test func joinTargetSkipsMeetingsWithoutLinks() {
        let noLink = timed("n", title: "Review", start: makeDate(2026, 3, 10, 10, 2), link: false)
        let linked = timed("l", start: makeDate(2026, 3, 10, 10, 30))
        let s = snapshot([noLink, linked])
        #expect(s.next == noLink)
        #expect(s.joinTarget == linked)
    }

    @Test func joinTargetIsNilWhenNothingHasALink() {
        let m = timed("n", title: "Review", start: makeDate(2026, 3, 10, 10, 20), link: false)
        #expect(snapshot([m]).joinTarget == nil)
    }

    @Test func sameStartMeetingsAreOrderedDeterministically() {
        let a = timed("b", title: "B", start: makeDate(2026, 3, 10, 10, 20))
        let b = timed("a", title: "A", start: makeDate(2026, 3, 10, 10, 20))
        #expect(snapshot([a, b]).upcoming.map(\.title) == ["A", "B"])
    }

    // MARK: DST and midnight

    @Test func countdownAcrossSpringForwardUsesRealElapsedTime() {
        let ny = TestCalendars.newYork
        let m = timed("a", start: makeDate(2026, 3, 8, 3, 30, calendar: ny))
        // 01:59 EST to 03:30 EDT is 31 real minutes: the wall clock skips 02:00-03:00.
        let s = snapshot([m], at: makeDate(2026, 3, 8, 1, 59, calendar: ny))
        #expect(s.status == .upcoming(m, secondsUntilStart: 31 * 60))
        #expect(MenuBarDisplay.make(status: s.status, mode: .countdown, titleLength: 20).countdown == .minutes(31))
    }

    @Test func meetingSpanningFallBackStaysOngoingThroughTheRepeatedHour() {
        // 01:30 EDT (05:30Z) to 02:00 EST (07:00Z); the wall clock reads 01:45 twice.
        let m = timed("a", start: makeDate(2026, 11, 1, 5, 30), minutes: 90)
        let firstPass = snapshot([m], at: makeDate(2026, 11, 1, 5, 45))
        let secondPass = snapshot([m], at: makeDate(2026, 11, 1, 6, 45))
        #expect(firstPass.status == .ongoing(m))
        #expect(secondPass.status == .ongoing(m))
        #expect(snapshot([m], at: makeDate(2026, 11, 1, 7, 0)).status == .idle)
    }

    @Test func countdownCrossesMidnight() {
        let m = timed("a", start: makeDate(2026, 3, 11, 0, 30))
        let s = snapshot([m], at: makeDate(2026, 3, 10, 23, 50))
        #expect(s.status == .upcoming(m, secondsUntilStart: 40 * 60))
    }

    @Test func meetingRunningPastMidnightIsOngoingOnBothSides() {
        let m = timed("a", start: makeDate(2026, 3, 10, 23, 30), minutes: 60)
        #expect(snapshot([m], at: makeDate(2026, 3, 10, 23, 59)).status == .ongoing(m))
        #expect(snapshot([m], at: makeDate(2026, 3, 11, 0, 10)).status == .ongoing(m))
        #expect(snapshot([m], at: makeDate(2026, 3, 11, 0, 30)).status == .idle)
    }

    @Test func zeroLengthMeetingIsUpcomingThenGone() {
        let m = timed("z", start: makeDate(2026, 3, 10, 10, 10), minutes: 0)
        #expect(snapshot([m]).next == m)
        #expect(snapshot([m], at: makeDate(2026, 3, 10, 10, 10)).status == .idle)
    }
}

@Suite struct NextWakeTests {
    private let config = TimelineConfig()

    private func wake(_ meetings: [Meeting], at now: Date) -> Date? {
        let snapshot = MeetingTimeline.snapshot(meetings: meetings, filter: nil, now: now)
        return MeetingTimeline.nextWake(for: snapshot, config: config)
    }

    @Test func minuteBoundaryIsStrictlyAfter() {
        #expect(MeetingTimeline.nextMinuteBoundary(after: makeDate(2026, 3, 10, 10, 0)) == makeDate(2026, 3, 10, 10, 1))
        #expect(MeetingTimeline.nextMinuteBoundary(after: makeDate(2026, 3, 10, 10, 0).addingTimeInterval(30)) == makeDate(2026, 3, 10, 10, 1))
        #expect(MeetingTimeline.nextMinuteBoundary(after: makeDate(2026, 3, 10, 10, 0).addingTimeInterval(59.9)) == makeDate(2026, 3, 10, 10, 1))
    }

    @Test func noMeetingsMeansNoWake() {
        #expect(wake([], at: makeDate(2026, 3, 10, 10, 0)) == nil)
    }

    @Test func onlyPastMeetingsMeanNoWake() {
        #expect(wake([timed("a", start: makeDate(2026, 3, 10, 8, 0))], at: makeDate(2026, 3, 10, 10, 0)) == nil)
    }

    @Test func ongoingMeetingWakesEveryMinute() {
        let m = timed("a", start: makeDate(2026, 3, 10, 9, 45))
        let now = makeDate(2026, 3, 10, 10, 0).addingTimeInterval(20)
        #expect(wake([m], at: now) == makeDate(2026, 3, 10, 10, 1))
    }

    @Test func upcomingWithinTheHorizonWakesEveryMinute() {
        let m = timed("a", start: makeDate(2026, 3, 10, 12, 0))
        #expect(wake([m], at: makeDate(2026, 3, 10, 10, 0)) == makeDate(2026, 3, 10, 10, 1))
    }

    @Test func farMeetingSleepsUntilItEntersTheHorizon() {
        let m = timed("a", start: makeDate(2026, 3, 11, 9, 0))
        // 23h away: the countdown starts 8h before, at 01:00.
        #expect(wake([m], at: makeDate(2026, 3, 10, 10, 0)) == makeDate(2026, 3, 11, 1, 0))
    }

    @Test func horizonEntryIsRoundedUpToAWholeMinute() {
        let start = makeDate(2026, 3, 11, 9, 0).addingTimeInterval(20)
        let m = timed("a", start: start)
        #expect(wake([m], at: makeDate(2026, 3, 10, 10, 0)) == makeDate(2026, 3, 11, 1, 1))
    }
}

@Suite struct MenuBarDisplayTests {
    private let meeting = timed("a", title: "Weekly product sync with the whole team", start: makeDate(2026, 3, 10, 10, 12))

    private func display(_ status: MenuBarStatus, _ mode: MenuBarMode, length: Int = 20) -> MenuBarDisplay {
        MenuBarDisplay.make(status: status, mode: mode, titleLength: length)
    }

    @Test func idleIsIconOnlyInEveryMode() {
        for mode in MenuBarMode.allCases {
            #expect(display(.idle, mode) == .iconOnly)
        }
    }

    @Test func countdownModeHasNoTitle() {
        let d = display(.upcoming(meeting, secondsUntilStart: 12 * 60), .countdown)
        #expect(d.title == nil)
        #expect(d.countdown == .minutes(12))
        #expect(!d.isImminent)
    }

    @Test func titleModeTruncatesWithEllipsis() {
        let d = display(.upcoming(meeting, secondsUntilStart: 12 * 60), .titleAndCountdown, length: 10)
        #expect(d.title == "Weekly pr…")
        #expect(d.title?.count == 10)
    }

    @Test func shortTitlesAreNotTruncated() {
        let short = timed("s", title: "Standup", start: meeting.start)
        #expect(display(.upcoming(short, secondsUntilStart: 600), .titleAndCountdown, length: 20).title == "Standup")
        #expect(display(.upcoming(short, secondsUntilStart: 600), .titleAndCountdown, length: 7).title == "Standup")
    }

    @Test func blankTitlesGiveNoTitle() {
        let blank = timed("b", title: "   ", start: meeting.start)
        #expect(display(.upcoming(blank, secondsUntilStart: 600), .titleAndCountdown).title == nil)
    }

    @Test func secondsRoundUpToWholeMinutes() {
        #expect(display(.upcoming(meeting, secondsUntilStart: 1), .countdown).countdown == .minutes(1))
        #expect(display(.upcoming(meeting, secondsUntilStart: 60), .countdown).countdown == .minutes(1))
        #expect(display(.upcoming(meeting, secondsUntilStart: 61), .countdown).countdown == .minutes(2))
        #expect(display(.upcoming(meeting, secondsUntilStart: 135 * 60), .countdown).countdown == .minutes(135))
    }

    @Test func imminentWithinFiveMinutes() {
        #expect(display(.upcoming(meeting, secondsUntilStart: 300), .countdown).isImminent)
        #expect(!display(.upcoming(meeting, secondsUntilStart: 301), .countdown).isImminent)
    }

    @Test func iconOnlyModeKeepsTheImminentTint() {
        let d = display(.upcoming(meeting, secondsUntilStart: 120), .iconOnly)
        #expect(d.title == nil)
        #expect(d.countdown == nil)
        #expect(d.isImminent)
    }

    @Test func ongoingShowsNowWithOptionalTitle() {
        #expect(display(.ongoing(meeting), .countdown).countdown == .now)
        #expect(display(.ongoing(meeting), .titleAndCountdown, length: 10).title == "Weekly pr…")
        #expect(display(.ongoing(meeting), .iconOnly) == .iconOnly)
    }
}
