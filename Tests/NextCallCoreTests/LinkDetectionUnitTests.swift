import Foundation
import Testing
@testable import NextCallCore

@Suite struct RedirectUnwrapperTests {
    private func unwrap(_ string: String) -> String {
        RedirectUnwrapper.unwrap(URL(string: string)!).absoluteString
    }

    @Test func unwrapsSafeLinksOfAnyRegion() {
        let inner = "https%3A%2F%2Fzoom.us%2Fj%2F123"
        #expect(unwrap("https://nam02.safelinks.protection.outlook.com/?url=\(inner)&data=x") == "https://zoom.us/j/123")
        #expect(unwrap("https://eur01.safelinks.protection.outlook.com/?url=\(inner)") == "https://zoom.us/j/123")
    }

    @Test func unwrapsGoogleRedirect() {
        #expect(unwrap("https://www.google.com/url?q=https://meet.google.com/abc-defg-hij&sa=D") == "https://meet.google.com/abc-defg-hij")
        #expect(unwrap("https://google.com/url?url=https://meet.google.com/abc-defg-hij") == "https://meet.google.com/abc-defg-hij")
    }

    @Test func googleSearchIsNotUnwrapped() {
        #expect(unwrap("https://www.google.com/search?q=https://zoom.us/j/1") == "https://www.google.com/search?q=https://zoom.us/j/1")
    }

    @Test func unwrapsProofpointVersions() {
        #expect(unwrap("https://urldefense.proofpoint.com/v1/url?u=https://zoom.us/j/1&k=a") == "https://zoom.us/j/1")
        #expect(unwrap("https://urldefense.proofpoint.com/v2/url?u=https-3A__zoom.us_j_1-3Fpwd-3Dx&d=a") == "https://zoom.us/j/1?pwd=x")
        #expect(unwrap("https://urldefense.com/v3/__https://zoom.us/j/1?pwd=x__;!!abc!def$") == "https://zoom.us/j/1?pwd=x")
    }

    @Test func proofpointV2KeepsLiteralDashes() {
        #expect(unwrap("https://urldefense.proofpoint.com/v2/url?u=https-3A__a.example_x-2Dy&d=a") == "https://a.example/x-y")
    }

    @Test func unwrapsNestedWrappers() {
        let google = "https%3A%2F%2Fwww.google.com%2Furl%3Fq%3Dhttps%3A%2F%2Fzoom.us%2Fj%2F9%26sa%3DD"
        #expect(unwrap("https://nam02.safelinks.protection.outlook.com/?url=\(google)") == "https://zoom.us/j/9")
    }

    @Test func leavesPlainAndMalformedLinksAlone() {
        #expect(unwrap("https://zoom.us/j/1") == "https://zoom.us/j/1")
        #expect(unwrap("https://nam02.safelinks.protection.outlook.com/?data=x") == "https://nam02.safelinks.protection.outlook.com/?data=x")
        #expect(unwrap("https://urldefense.com/v3/nothing") == "https://urldefense.com/v3/nothing")
    }

    @Test func stopsOnWrapperLoops() {
        let loop = "https://www.google.com/url?q=https://www.google.com/url?q=https://www.google.com/url"
        #expect(!unwrap(loop).isEmpty)
    }

    @Test func safeLinksLookalikeHostIsNotUnwrapped() {
        let url = "https://safelinks.protection.outlook.com.evil.example/?url=https%3A%2F%2Fzoom.us%2Fj%2F1"
        #expect(unwrap(url) == url)
    }
}

@Suite struct TextNormalizerTests {
    @Test func stripsTagsStylesAndScripts() {
        let html = "<style>a{}</style><p>Hello<br>world</p><script>var x='<a>'</script>"
        let text = TextNormalizer.plainText(from: html)
        #expect(text.contains("Hello"))
        #expect(text.contains("world"))
        #expect(!text.contains("var x"))
        #expect(!text.contains("a{}"))
    }

    @Test func keepsAngleBracketUrlsFromPlainText() {
        #expect(TextNormalizer.plainText(from: "Join <https://zoom.us/j/1> now").contains("https://zoom.us/j/1"))
    }

    @Test func anchorHrefBecomesVisibleText() {
        let text = TextNormalizer.plainText(from: #"<a href="https://zoom.us/j/1?a=1&amp;b=2">Join</a>"#)
        #expect(text.contains("https://zoom.us/j/1?a=1&b=2"))
    }

    @Test func decodesNamedAndNumericEntities() {
        #expect(HTMLEntities.decode("a &amp; b &lt;c&gt; &quot;d&quot; &#39;e&#39; &#x41; &unknown;") == "a & b <c> \"d\" 'e' A &unknown;")
    }

    @Test func leavesBareAmpersandsInUrlsAlone() {
        #expect(HTMLEntities.decode("https://x.example/?a=1&b=2&c") == "https://x.example/?a=1&b=2&c")
    }

    @Test func removesZeroWidthAndNbsp() {
        #expect(TextNormalizer.plainText(from: "a\u{200B}b\u{00A0}c") == "ab c")
    }
}

@Suite struct NativeURLBuilderTests {
    private func native(_ scheme: NativeScheme, _ url: String) -> String? {
        NativeURLBuilder.build(scheme, from: URL(string: url)!)?.absoluteString
    }

    @Test func zoomBuildsJoinURLWithOptionalPassword() {
        #expect(native(.zoom, "https://zoom.us/j/123456789") == "zoommtg://zoom.us/join?confno=123456789")
        #expect(native(.zoom, "https://zoom.us/j/123456789?pwd=abc") == "zoommtg://zoom.us/join?confno=123456789&pwd=abc")
    }

    @Test func zoomHasNoNativeURLForPersonalRoomsOrWebinars() {
        #expect(native(.zoom, "https://zoom.us/my/tim") == nil)
        #expect(native(.zoom, "https://zoom.us/w/123456789") == nil)
        #expect(native(.zoom, "https://zoom.us/j/notnumeric") == nil)
    }

    @Test func teamsSwapsHostForScheme() {
        #expect(native(.teams, "https://teams.microsoft.com/l/meetup-join/19%3ax/0?context=%7b%7d") == "msteams:/l/meetup-join/19%3ax/0?context=%7b%7d")
        #expect(native(.teams, "https://teams.microsoft.com/meet/123?p=x") == nil)
    }

    @Test func noneNeverBuilds() {
        #expect(native(.none, "https://meet.google.com/abc-defg-hij") == nil)
    }
}

@Suite struct ProviderRegistryTests {
    @Test func everyProviderHasARule() {
        let covered = Set(ProviderRegistry.rules.map(\.provider))
        #expect(covered == Set(Provider.allCases))
    }

    @Test func atLeastTwentyProviders() {
        #expect(Set(ProviderRegistry.rules.map(\.provider)).count >= 20)
    }

    @Test func detectorBuildsFromAllRules() {
        // Compiling every pattern would trap on a malformed regex in the registry data.
        _ = MeetingLinkDetector(rules: ProviderRegistry.rules)
    }

    @Test func customRulesCanBeInjected() {
        let rule = ProviderRule(.pop, host: #"^calls\.example\.com$"#, path: #"^/r/.+"#)
        let detector = MeetingLinkDetector(rules: [rule])
        let link = detector.detect(url: nil, location: "https://calls.example.com/r/abc", notes: nil)
        #expect(link?.provider == .pop)
        #expect(detector.detect(url: nil, location: "https://zoom.us/j/123456789", notes: nil) == nil)
    }
}

@Suite struct MeetingLinkDetectorBehaviorTests {
    private let detector = MeetingLinkDetector.standard

    @Test func emptyAndNilInputsGiveNoLink() {
        #expect(detector.detect(url: nil, location: nil, notes: nil) == nil)
        #expect(detector.detect(url: nil, location: "", notes: "") == nil)
    }

    @Test func nonWebURLFieldIsIgnored() {
        #expect(detector.detect(url: URL(string: "file:///tmp/zoom.us/j/123456789"), location: nil, notes: nil) == nil)
        #expect(detector.detect(url: URL(string: "mailto:a@zoom.us"), location: nil, notes: nil) == nil)
    }

    @Test func veryLongNotesWithoutLinksFinishQuickly() {
        let notes = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 2_000)
        let start = ContinuousClock.now
        #expect(detector.detect(url: nil, location: nil, notes: notes) == nil)
        #expect(ContinuousClock.now - start < .seconds(2))
    }

    @Test func fixtureHarnessReportsMismatches() {
        let wrong = LinkFixture(
            id: "self-test", description: "", url: nil, location: "https://zoom.us/j/123456789", notes: nil,
            expect: .init(provider: "googleMeet", url: "https://meet.google.com/abc-defg-hij", native: nil)
        )
        #expect(wrong.mismatch(using: detector) != nil)
    }

    @Test func serviceAttachesDetectedLinkToMeetings() async {
        let event = RawEvent(
            id: "e", title: "Sync", start: makeDate(2026, 3, 10, 10), end: makeDate(2026, 3, 10, 11),
            calendar: makeCalendarRef(), location: "https://meet.google.com/abc-defg-hij"
        )
        let service = CalendarService(
            dataSource: FakeDataSource(events: [event]),
            changes: { AsyncStream { $0.finish() } },
            calendar: TestCalendars.utc,
            now: { makeDate(2026, 3, 10, 9) }
        )
        let snapshot = await service.snapshot(days: 1, excludingCalendarIDs: [])
        #expect(snapshot.meetings.first?.link?.provider == .googleMeet)
    }
}

@Suite struct LenientURLTests {
    @Test func parsesWellFormedURLsUnchanged() {
        #expect(URL.lenient("https://zoom.us/j/1?pwd=a")?.absoluteString == "https://zoom.us/j/1?pwd=a")
    }

    @Test func escapesRawBracesAndQuotesWithoutDoubleEscaping() {
        let url = URL.lenient(#"https://teams.microsoft.com/l/meetup-join/x?context={"Tid":"a%20b"}"#)
        #expect(url?.host == "teams.microsoft.com")
        #expect(url?.absoluteString.contains("%7B%22Tid%22") == true)
        #expect(url?.absoluteString.contains("a%20b") == true)
    }

    @Test func rejectsStringsThatCannotBecomeURLs() {
        #expect(URL.lenient("") == nil)
    }
}
