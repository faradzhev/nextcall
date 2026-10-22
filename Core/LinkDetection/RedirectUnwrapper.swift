import Foundation

/// Removes link-protection and redirect wrappers (Outlook SafeLinks, google.com/url, Proofpoint, ...).
/// Mimecast links carry no target URL, so they cannot be unwrapped.
enum RedirectUnwrapper {
    private static let maxDepth = 5

    static func unwrap(_ url: URL) -> URL {
        var current = url
        for _ in 0..<maxDepth {
            guard let next = unwrapOnce(current), next != current else { break }
            current = next
        }
        return current
    }

    private static func unwrapOnce(_ url: URL) -> URL? {
        guard let host = url.host?.lowercased(),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        let path = components.path

        func parameter(_ name: String) -> String? {
            components.queryItems?.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        if host == "safelinks.protection.outlook.com" || host.hasSuffix(".safelinks.protection.outlook.com") {
            return parameter("url").flatMap(URL.lenient)
        }
        if host == "google.com" || host == "www.google.com", path == "/url" {
            return (parameter("q") ?? parameter("url")).flatMap(URL.lenient)
        }
        if host == "urldefense.proofpoint.com" || host == "urldefense.com" || host == "urldefense.us" {
            return unwrapProofpoint(url, path: path, parameter: parameter)
        }
        if host == "linkprotect.cudasvc.com", path == "/url" {
            return parameter("a").flatMap(URL.lenient)
        }
        if host == "outlook.office365.com" || host == "outlook.office.com" || host == "outlook.live.com",
           path.hasPrefix("/owa/redir.aspx") {
            return parameter("URL").flatMap(URL.lenient)
        }
        return nil
    }

    private static func unwrapProofpoint(_ url: URL, path: String, parameter: (String) -> String?) -> URL? {
        if path.hasPrefix("/v1/url") {
            return parameter("u").flatMap(URL.lenient)
        }
        if path.hasPrefix("/v2/url") {
            // v2 swaps "%" for "-" and "/" for "_" before encoding the rest.
            return parameter("u")
                .map { $0.replacingOccurrences(of: "-", with: "%").replacingOccurrences(of: "_", with: "/") }
                .flatMap { $0.removingPercentEncoding }
                .flatMap(URL.lenient)
        }
        if path.hasPrefix("/v3/") {
            let string = url.absoluteString
            guard let start = string.range(of: "/v3/__"),
                  let end = string.range(of: "__;", range: start.upperBound..<string.endIndex)
            else { return nil }
            return URL.lenient(String(string[start.upperBound..<end.lowerBound]))
        }
        return nil
    }
}
