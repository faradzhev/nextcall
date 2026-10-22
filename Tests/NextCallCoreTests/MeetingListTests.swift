import Foundation
import Testing
@testable import NextCallCore

@Suite struct MeetingListTests {
    private let calendar = TestCalendars.utc
    private let now = makeDate(2026, 3, 10, 12)

    private func options(
        allDay: Bool = true,
        hideDeclined: Bool = false,
        past: PastEventsMode = .dimmed
    ) -> MeetingListOptions {
        MeetingListOptions(showAllDay: allDay, hideDeclined: hideDeclined, pastEvents: past)
    }

    @Test func groupsByDayInOrder() {
        let meetings = [
            makeMeeting("c", start: makeDate(2026, 3, 11, 9)),
            makeMeeting("a", start: makeDate(2026, 3, 10, 13)),
            makeMeeting("b", start: makeDate(2026, 3, 10, 15)),
        ]
        let sections = MeetingList.sections(meetings, options: options(), now: now, calendar: calendar)
        #expect(sections.map(\.day) == [makeDate(2026, 3, 10), makeDate(2026, 3, 11)])
        #expect(sections[0].meetings.map(\.id) == ["a", "b"])
        #expect(sections[1].meetings.map(\.id) == ["c"])
    }

    @Test func hidesDeclinedOnlyWhenAsked() {
        let meetings = [makeMeeting("d", start: makeDate(2026, 3, 10, 14), status: .declined)]
        #expect(MeetingList.sections(meetings, options: options(hideDeclined: true), now: now, calendar: calendar).isEmpty)
        #expect(MeetingList.sections(meetings, options: options(hideDeclined: false), now: now, calendar: calendar).count == 1)
    }

    @Test func allDayEventsFollowTheToggleAndComeFirst() {
        let meetings = [
            makeMeeting("t", start: makeDate(2026, 3, 10, 9)),
            makeMeeting("ad", start: makeDate(2026, 3, 10), minutes: 1440, allDay: true),
        ]
        let shown = MeetingList.sections(meetings, options: options(allDay: true), now: now, calendar: calendar)
        #expect(shown[0].meetings.map(\.id) == ["ad", "t"])
        let hidden = MeetingList.sections(meetings, options: options(allDay: false), now: now, calendar: calendar)
        #expect(hidden[0].meetings.map(\.id) == ["t"])
    }

    @Test func pastEventsAreHiddenOrKept() {
        let meetings = [
            makeMeeting("past", start: makeDate(2026, 3, 10, 9)),
            makeMeeting("now", start: makeDate(2026, 3, 10, 11, 45)),
            makeMeeting("next", start: makeDate(2026, 3, 10, 14)),
        ]
        let hidden = MeetingList.sections(meetings, options: options(past: .hidden), now: now, calendar: calendar)
        #expect(hidden[0].meetings.map(\.id) == ["now", "next"])
        let dimmed = MeetingList.sections(meetings, options: options(past: .dimmed), now: now, calendar: calendar)
        #expect(dimmed[0].meetings.map(\.id) == ["past", "now", "next"])
    }

    @Test func eventEndingExactlyNowIsPast() {
        let meeting = makeMeeting("edge", start: makeDate(2026, 3, 10, 11, 30), minutes: 30)
        #expect(meeting.isPast(at: now))
        #expect(!meeting.isOngoing(at: now))
    }

    @Test func overnightMeetingStartedYesterdayListsUnderToday() {
        let meetings = [makeMeeting("night", start: makeDate(2026, 3, 9, 23), minutes: 180)]
        let sections = MeetingList.sections(meetings, options: options(), now: makeDate(2026, 3, 10, 0, 30), calendar: calendar)
        #expect(sections.map(\.day) == [makeDate(2026, 3, 10)])
    }

    @Test func midnightRolloverMovesTomorrowIntoToday() {
        let meetings = [makeMeeting("m", start: makeDate(2026, 3, 11, 9))]
        let before = MeetingList.sections(meetings, options: options(), now: makeDate(2026, 3, 10, 23, 59), calendar: calendar)
        let after = MeetingList.sections(meetings, options: options(), now: makeDate(2026, 3, 11, 0, 1), calendar: calendar)
        #expect(before[0].day == makeDate(2026, 3, 11))
        #expect(after[0].day == makeDate(2026, 3, 11))
        #expect(calendar.isDate(after[0].day, inSameDayAs: makeDate(2026, 3, 11, 0, 1)))
    }

    @Test func overlappingMeetingsKeepStartOrder() {
        let meetings = [
            makeMeeting("long", start: makeDate(2026, 3, 10, 13), minutes: 120),
            makeMeeting("short", start: makeDate(2026, 3, 10, 13, 30), minutes: 30),
        ]
        let sections = MeetingList.sections(meetings, options: options(), now: now, calendar: calendar)
        #expect(sections[0].meetings.map(\.id) == ["long", "short"])
        #expect(meetings.allSatisfy { $0.isOngoing(at: makeDate(2026, 3, 10, 13, 45)) })
    }

    @Test func emptyInputGivesNoSections() {
        #expect(MeetingList.sections([], options: options(), now: now, calendar: calendar).isEmpty)
    }
}
