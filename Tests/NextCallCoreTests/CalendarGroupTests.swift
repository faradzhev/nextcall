import Testing
@testable import NextCallCore

@Suite struct CalendarGroupTests {
    @Test func groupsBySourceAndSortsNames() {
        let calendars = [
            makeCalendarRef(id: "1", title: "work", source: "iCloud", sourceID: "i"),
            makeCalendarRef(id: "2", title: "Family", source: "iCloud", sourceID: "i"),
            makeCalendarRef(id: "3", title: "Team", source: "Exchange", sourceID: "e"),
        ]
        let groups = CalendarGroup.groups(from: calendars)
        #expect(groups.map(\.source.title) == ["Exchange", "iCloud"])
        #expect(groups[1].calendars.map(\.title) == ["Family", "work"])
    }

    @Test func emptyInputGivesNoGroups() {
        #expect(CalendarGroup.groups(from: []).isEmpty)
    }
}
