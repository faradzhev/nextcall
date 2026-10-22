import EventKit
import Testing
@testable import NextCallCore

@Suite struct EventKitMappingTests {
    @Test func authorizationMapping() {
        #expect(EventKitDataSource.map(.fullAccess) == .granted)
        #expect(EventKitDataSource.map(.notDetermined) == .notDetermined)
        #expect(EventKitDataSource.map(.restricted) == .restricted)
        #expect(EventKitDataSource.map(.denied) == .denied)
        #expect(EventKitDataSource.map(.writeOnly) == .denied)
    }

    @Test func participantStatusMapping() {
        #expect(EventKitDataSource.map(EKParticipantStatus.accepted) == .accepted)
        #expect(EventKitDataSource.map(EKParticipantStatus.declined) == .declined)
        #expect(EventKitDataSource.map(EKParticipantStatus.tentative) == .tentative)
        #expect(EventKitDataSource.map(EKParticipantStatus.pending) == .pending)
        #expect(EventKitDataSource.map(EKParticipantStatus.unknown) == .unknown)
    }

    @Test func availabilityMappingTreatsUnsupportedAsBusy() {
        #expect(EventKitDataSource.map(EKEventAvailability.free) == .free)
        #expect(EventKitDataSource.map(EKEventAvailability.busy) == .busy)
        #expect(EventKitDataSource.map(EKEventAvailability.tentative) == .tentative)
        #expect(EventKitDataSource.map(EKEventAvailability.unavailable) == .unavailable)
        #expect(EventKitDataSource.map(EKEventAvailability.notSupported) == .busy)
    }

    @Test func eventMappingKeepsOccurrenceStartInID() throws {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "Standup"
        event.startDate = makeDate(2026, 3, 10, 9)
        event.endDate = makeDate(2026, 3, 10, 9, 30)
        event.isAllDay = false
        event.location = "https://meet.google.com/abc-defg-hij"
        #expect(EventKitDataSource.map(event) == nil) // no calendar yet
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "Work"
        event.calendar = calendar
        let raw = try #require(EventKitDataSource.map(event))
        #expect(raw.title == "Standup")
        #expect(raw.id.hasSuffix("|\(makeDate(2026, 3, 10, 9).timeIntervalSinceReferenceDate)"))
        #expect(raw.location == "https://meet.google.com/abc-defg-hij")
        #expect(raw.attendeeCount == 0)
        #expect(raw.myStatus == .unknown)
        #expect(!raw.isCanceled)
        #expect(raw.calendar.title == "Work")
        #expect(raw.calendar.source.title.isEmpty) // unsaved calendar has no source
    }
}
