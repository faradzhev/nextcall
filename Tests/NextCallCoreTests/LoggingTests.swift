import Testing
@testable import NextCallCore

@Suite struct LoggingTests {
    @Test func subsystemMatchesBundlePrefix() {
        #expect(Log.subsystem == "com.frdzhv.NextCall")
    }
}
