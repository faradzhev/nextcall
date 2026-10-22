import Foundation
import Testing
@testable import NextCallCore

@Suite struct EventFilterTests {
    private let filter = EventFilter()
    private let start = makeDate(2026, 3, 10, 10)

    private func meeting(
        _ title: String = "Planning",
        attendees: Int = 4,
        availability: EventAvailability = .busy,
        link: Bool = false
    ) -> Meeting {
        let raw = makeEvent(title: title, start: start, attendees: attendees, availability: availability)
        let link = link ? MeetingLink(provider: .zoom, url: URL(string: "https://zoom.us/j/123456789")!, nativeURL: nil) : nil
        return Meeting(raw: raw, link: link)
    }

    // MARK: Order of rules

    @Test func linkAlwaysWinsOverEveryOtherRule() {
        let m = meeting("Lunch", attendees: 0, availability: .free, link: true)
        #expect(filter.classify(m) == .meeting)
    }

    @Test func soloEventWithoutLinkIsPersonal() {
        #expect(filter.classify(meeting(attendees: 0)) == .personal(.solo))
        #expect(filter.classify(meeting(attendees: 1)) == .personal(.solo)) // only the user
    }

    @Test func freeEventWithAttendeesIsPersonal() {
        #expect(filter.classify(meeting(availability: .free)) == .personal(.free))
    }

    @Test func keywordInTitleIsPersonalEvenWithAttendees() {
        #expect(filter.classify(meeting("Team Lunch")) == .personal(.keyword("Lunch")))
    }

    @Test func soloRuleReportedBeforeKeyword() {
        #expect(filter.classify(meeting("Lunch", attendees: 0)) == .personal(.solo))
    }

    @Test func ordinaryMeetingWithoutLinkStaysAMeeting() {
        #expect(filter.classify(meeting("Quarterly review", attendees: 6)) == .meeting)
    }

    @Test func tentativeAndUnavailableAreNotFree() {
        #expect(filter.classify(meeting(availability: .tentative)) == .meeting)
        #expect(filter.classify(meeting(availability: .unavailable)) == .meeting)
    }

    // MARK: Keywords

    @Test(arguments: ["lunch", "LUNCH", "Lunch", "Team lunch break", "Lunch & learn", "Busy.", "(Focus)", "Focus: writing", "Commute home"])
    func keywordsMatchCaseInsensitivelyAsWholeWords(title: String) {
        #expect(filter.isPersonal(meeting(title)))
    }

    @Test(arguments: ["Blocker triage", "Holdings review", "Unfocused chat", "Lunchbox design", "Busyness metrics", "Booth"])
    func keywordsDoNotMatchInsideLongerWords(title: String) {
        #expect(!filter.isPersonal(meeting(title)))
    }

    @Test func multiWordPhraseMatches() {
        #expect(filter.isPersonal(meeting("Out of office until Monday")))
        #expect(filter.isPersonal(meeting("out   of   office".replacingOccurrences(of: "   ", with: " "))))
        #expect(!filter.isPersonal(meeting("Out of the office tour")))
    }

    @Test func defaultKeywordsAreTheDocumentedOnes() {
        #expect(EventFilterRules.defaultIgnoreKeywords == ["Lunch", "Busy", "Focus", "OOO", "Out of office", "Commute", "Hold", "Block"])
        for keyword in EventFilterRules.defaultIgnoreKeywords {
            #expect(filter.isPersonal(meeting("Daily \(keyword)")), "\(keyword)")
        }
    }

    @Test func customKeywordsReplaceDefaults() {
        let custom = EventFilter(rules: EventFilterRules(ignoreKeywords: ["Gym"]))
        #expect(custom.isPersonal(meeting("Gym")))
        #expect(!custom.isPersonal(meeting("Lunch")))
    }

    @Test func nonLatinKeywordsMatchWholeWords() {
        let custom = EventFilter(rules: EventFilterRules(ignoreKeywords: ["Обід"]))
        #expect(custom.isPersonal(meeting("Обід з командою")))
        #expect(custom.isPersonal(meeting("обід")))
        #expect(!custom.isPersonal(meeting("Обіднє засідання")))
    }

    @Test func regexMetacharactersInKeywordsAreLiteral() {
        let custom = EventFilter(rules: EventFilterRules(ignoreKeywords: ["C++ (draft)", ".*"]))
        #expect(custom.isPersonal(meeting("C++ (draft) review")))
        #expect(!custom.isPersonal(meeting("C review")))
        #expect(!custom.isPersonal(meeting("Anything")))
    }

    @Test func blankKeywordsAreIgnored() {
        let custom = EventFilter(rules: EventFilterRules(ignoreKeywords: ["", "  "], ignoreSoloEvents: false, ignoreFreeEvents: false))
        #expect(!custom.isPersonal(meeting("Anything")))
    }

    // MARK: Toggles

    @Test func soloAndFreeRulesCanBeSwitchedOff() {
        let relaxed = EventFilter(rules: EventFilterRules(ignoreKeywords: [], ignoreSoloEvents: false, ignoreFreeEvents: false))
        #expect(relaxed.classify(meeting(attendees: 0)) == .meeting)
        #expect(relaxed.classify(meeting(availability: .free)) == .meeting)
    }

    // MARK: Integration with the list

    @Test func hiddenModeDropsPersonalBlocksButDimmedKeepsThem() {
        let meetings = [
            meeting("Planning"),
            meeting("Lunch"),
            Meeting(raw: makeEvent(title: "Focus", start: start, attendees: 0), link: MeetingLink(provider: .googleMeet, url: URL(string: "https://meet.google.com/abc-defg-hij")!, nativeURL: nil)),
        ]
        let now = makeDate(2026, 3, 10, 8)
        func titles(_ mode: IgnoredEventsMode) -> [String] {
            let options = MeetingListOptions(showAllDay: true, hideDeclined: false, pastEvents: .dimmed, ignoredEvents: mode)
            return MeetingList.sections(meetings, options: options, filter: filter, now: now, calendar: TestCalendars.utc)
                .flatMap(\.meetings).map(\.title).sorted()
        }
        #expect(titles(.hidden) == ["Focus", "Planning"]) // Focus has a link, so it is a meeting
        #expect(titles(.dimmed) == ["Focus", "Lunch", "Planning"])
    }
}
