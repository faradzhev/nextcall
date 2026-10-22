import Foundation

/// Finds the video-call link of an event. Pure and `Sendable`: candidates are read from
/// `url`, then `location`, then `notes`; the first URL (in document order) that matches a
/// provider rule wins.
public struct MeetingLinkDetector: Sendable {
    public static let standard = MeetingLinkDetector()

    private struct CompiledRule: Sendable {
        let rule: ProviderRule
        let host: Pattern
        let path: Pattern
    }

    private let rules: [CompiledRule]
    private let extractor = LinkExtractor()

    public init(rules: [ProviderRule] = ProviderRegistry.rules) {
        self.rules = rules.map { rule in
            CompiledRule(
                rule: rule,
                host: Pattern(rule.hostPattern),
                path: Pattern(rule.pathPattern)
            )
        }
    }

    public func detect(url: URL?, location: String?, notes: String?) -> MeetingLink? {
        if let url, let link = link(for: url) { return link }
        for field in [location, notes] {
            guard let field, !field.isEmpty else { continue }
            for candidate in extractor.urls(in: field) {
                if let link = link(for: candidate) { return link }
            }
        }
        return nil
    }

    /// The link for one URL after unwrapping redirects, or nil when no provider matches.
    func link(for url: URL) -> MeetingLink? {
        let target = RedirectUnwrapper.unwrap(url)
        guard let scheme = target.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = target.host?.lowercased()
        else { return nil }
        let path = target.path

        for compiled in rules {
            guard compiled.host.hasMatch(in: host), compiled.path.hasMatch(in: path),
                  let cleaned = clean(target, with: compiled.rule)
            else { continue }
            return MeetingLink(
                provider: compiled.rule.provider,
                url: cleaned,
                nativeURL: NativeURLBuilder.build(compiled.rule.native, from: cleaned)
            )
        }
        return nil
    }

    private func clean(_ url: URL, with rule: ProviderRule) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = "https"
        components.host = components.host?.lowercased()
        components.user = nil
        components.password = nil
        components.port = nil
        if !rule.keepFragment { components.fragment = nil }
        if case let .only(names) = rule.query {
            let kept = components.percentEncodedQueryItems?.filter { names.contains($0.name) } ?? []
            components.percentEncodedQueryItems = kept.isEmpty ? nil : kept
        }
        return components.url
    }
}
