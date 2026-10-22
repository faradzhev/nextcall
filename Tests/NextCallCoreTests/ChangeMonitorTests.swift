import AppKit
import EventKit
import Foundation
import Testing
@testable import NextCallCore

@Suite struct ChangeMonitorTests {
    @Test func mapsSystemNotificationsToReasons() async {
        let center = NotificationCenter()
        let workspace = NotificationCenter()
        let monitor = ChangeMonitor(center: center, workspaceCenter: workspace)
        var iterator = monitor.changes().makeAsyncIterator()

        center.post(name: .EKEventStoreChanged, object: nil)
        #expect(await iterator.next() == .eventStore)

        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        #expect(await iterator.next() == .wake)

        center.post(name: .NSCalendarDayChanged, object: nil)
        #expect(await iterator.next() == .dayChanged)

        center.post(name: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil)
        #expect(await iterator.next() == .timeZone)

        center.post(name: NSNotification.Name.NSSystemClockDidChange, object: nil)
        #expect(await iterator.next() == .clock)
    }

    @Test func ignoresWakeOnTheWrongCenter() async throws {
        let center = NotificationCenter()
        let workspace = NotificationCenter()
        let monitor = ChangeMonitor(center: center, workspaceCenter: workspace)
        let collector = Collector<ChangeReason>()
        let task = Task { for await reason in monitor.changes() { await collector.add(reason) } }
        try await Task.sleep(for: .milliseconds(50))
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        #expect(await collector.items.isEmpty)
    }
}
