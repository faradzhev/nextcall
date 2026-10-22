import Foundation

/// Builds native-app deep links from cleaned meeting URLs.
enum NativeURLBuilder {
    static func build(_ scheme: NativeScheme, from url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host
        else { return nil }
        let path = components.percentEncodedPath
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        let segments = path.split(separator: "/").map(String.init)

        switch scheme {
        case .none:
            return nil
        case .zoom:
            // Only numeric meeting IDs can be joined natively; /my/<name> and webinars open in the browser.
            guard let id = segments.last, segments.first == "j" || segments.starts(with: ["wc", "join"]),
                  id.allSatisfy(\.isNumber)
            else { return nil }
            var result = "zoommtg://\(host)/join?confno=\(id)"
            if let pwd = components.percentEncodedQueryItems?.first(where: { $0.name == "pwd" })?.value {
                result += "&pwd=\(pwd)"
            }
            return URL(string: result)
        case .teams:
            guard path.hasPrefix("/l/meetup-join/") else { return nil }
            return URL(string: "msteams:\(path)\(query)")
        case .webex:
            return URL(string: "webex://\(host)\(path)\(query)")
        case .slack:
            guard segments.count >= 3, segments[0] == "huddle" else { return nil }
            return URL(string: "slack://channel?team=\(segments[1])&id=\(segments[2])")
        case .discord:
            if host == "discord.gg", let code = segments.first {
                return URL(string: "discord://-/invite/\(code)")
            }
            guard segments.count >= 3, segments[0] == "channels" else { return nil }
            return URL(string: "discord://-/channels/\(segments[1])/\(segments[2])")
        case .jitsi:
            return URL(string: "jitsi-meet://\(host)\(path)")
        }
    }
}
