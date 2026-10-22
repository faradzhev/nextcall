import Foundation
import Testing
@testable import NextCallCore

struct LinkFixture: Decodable, Sendable, CustomTestStringConvertible {
    struct Expectation: Decodable, Sendable, Equatable {
        let provider: String
        let url: String
        let native: String?
    }

    let id: String
    let description: String
    let url: String?
    let location: String?
    let notes: String?
    let expect: Expectation?

    var testDescription: String { id }

    static let all: [LinkFixture] = {
        let bundle = Bundle(for: FixtureBundleToken.self)
        guard let url = bundle.url(forResource: "link-detection", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let fixtures = try? JSONDecoder().decode([LinkFixture].self, from: data)
        else { return [] }
        return fixtures
    }()

    /// Runs the detector and returns a human-readable mismatch, or nil when the fixture passes.
    func mismatch(using detector: MeetingLinkDetector) -> String? {
        let link = detector.detect(url: url.flatMap { URL(string: $0) }, location: location, notes: notes)
        switch (expect, link) {
        case (nil, nil):
            return nil
        case let (expected?, actual?):
            let got = Expectation(provider: actual.provider.rawValue, url: actual.url.absoluteString, native: actual.nativeURL?.absoluteString)
            return got == expected ? nil : "\(id): expected \(expected), got \(got)"
        case let (expected?, nil):
            return "\(id): expected \(expected), got no link"
        case let (nil, actual?):
            return "\(id): expected no link, got \(actual.provider.rawValue) \(actual.url.absoluteString)"
        }
    }
}

private final class FixtureBundleToken {}

@Suite struct LinkDetectionFixtureTests {
    private let detector = MeetingLinkDetector.standard

    @Test func fixtureSetIsLargeEnough() {
        #expect(LinkFixture.all.count >= 50)
        #expect(LinkFixture.all.filter { $0.expect == nil }.count >= 5, "needs negative cases")
        let providers = Set(LinkFixture.all.compactMap { $0.expect?.provider })
        #expect(providers.count >= 20, "every provider should appear in at least one fixture")
    }

    @Test(arguments: LinkFixture.all)
    func fixtureMatchesExpectation(_ fixture: LinkFixture) {
        #expect(fixture.mismatch(using: detector) == nil)
    }

    @Test func accuracyOnFixturesIsAtLeast98Percent() {
        let fixtures = LinkFixture.all
        let failures = fixtures.compactMap { $0.mismatch(using: detector) }
        let accuracy = Double(fixtures.count - failures.count) / Double(max(fixtures.count, 1))
        #expect(accuracy >= 0.98, "accuracy \(accuracy); failures: \(failures)")
    }

    @Test func everyRegistryProviderIsCoveredByAFixture() {
        let covered = Set(LinkFixture.all.compactMap { $0.expect?.provider })
        let missing = Provider.allCases.map(\.rawValue).filter { !covered.contains($0) }
        #expect(missing.isEmpty, "providers without fixtures: \(missing)")
    }

    @Test func detectsLinksInUnderOneSecondFor200Events() {
        let fixtures = LinkFixture.all
        let start = ContinuousClock.now
        for index in 0..<200 {
            let f = fixtures[index % fixtures.count]
            _ = detector.detect(url: f.url.flatMap { URL(string: $0) }, location: f.location, notes: f.notes)
        }
        #expect(ContinuousClock.now - start < .seconds(1))
    }
}
