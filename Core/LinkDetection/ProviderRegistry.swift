import Foundation

public enum ProviderRegistry {
    public static let rules: [ProviderRule] = [
        ProviderRule(
            .zoom,
            host: #"(^|\.)(zoom\.us|zoom\.com|zoomgov\.com)$"#,
            path: #"^/(j|my|w|wc/join)/[^/]+"#,
            query: .only(["pwd", "tk"]),
            native: .zoom
        ),
        ProviderRule(
            .googleMeet,
            host: #"^meet\.google\.com$"#,
            path: #"^/([a-z]{3}-[a-z]{4}-[a-z]{3}|lookup/[A-Za-z0-9_-]+)(/|$)"#,
            query: .only(["authuser"])
        ),
        ProviderRule(
            .teams,
            host: #"(^|\.)teams\.microsoft\.(com|us)$|^teams\.live\.com$"#,
            path: #"^/(l/meetup-join/|meet/)[^/]+"#,
            native: .teams
        ),
        ProviderRule(
            .webex,
            host: #"(^|\.)webex\.com$"#,
            path: #"^/(meet/|join/|wbxmjs/joinservice/)[^/]+|/j\.php$"#,
            native: .webex
        ),
        ProviderRule(
            .slackHuddle,
            host: #"^app\.slack\.com$"#,
            path: #"^/huddle/[A-Z0-9]+/[A-Z0-9]+"#,
            native: .slack
        ),
        ProviderRule(
            .faceTime,
            host: #"^facetime\.apple\.com$"#,
            path: #"^/join"#,
            keepFragment: true
        ),
        ProviderRule(
            .jitsi,
            host: #"^(meet\.jit\.si|8x8\.vc|[a-z0-9-]+\.jitsi\.net)$"#,
            path: #"^/[^/]+"#,
            native: .jitsi
        ),
        ProviderRule(
            .whereby,
            host: #"(^|\.)whereby\.com$"#,
            path: #"^/(?!(information|about|pricing|blog|embedded|legal|careers|support|download|login|signup)/?$)[A-Za-z0-9_-]{2,}/?$"#
        ),
        ProviderRule(
            .goTo,
            host: #"(^|\.)(gotomeeting\.com|goto\.com)$"#,
            path: #"^/(join/\d+|meeting/\d+|\d{9,})"#
        ),
        ProviderRule(.chime, host: #"^(app\.)?chime\.aws$"#, path: #"^/(\d{10}|meetings/[A-Za-z0-9-]+)"#),
        ProviderRule(.ringCentral, host: #"^(meetings|v)\.ringcentral\.com$"#, path: #"^/(j|join)/\d+"#),
        ProviderRule(.blueJeans, host: #"(^|\.)bluejeans\.com$"#, path: #"^/\d{6,}"#),
        ProviderRule(
            .discord,
            host: #"^(discord|discordapp)\.com$"#,
            path: #"^/channels/\d+/\d+"#,
            native: .discord
        ),
        ProviderRule(.discord, host: #"^discord\.gg$"#, path: #"^/[A-Za-z0-9-]+$"#, native: .discord),
        ProviderRule(.skype, host: #"^join\.skype\.com$"#, path: #"^/[A-Za-z0-9]+"#),
        ProviderRule(.skype, host: #"^meet\.lync\.com$"#, path: #"^/[^/]+/[^/]+/[A-Za-z0-9]+"#),
        ProviderRule(.around, host: #"(^|\.)around\.co$"#, path: #"^/r/[^/]+"#),
        ProviderRule(
            .zoho,
            host: #"^(meeting|meet)\.zoho\.(com|eu|in|com\.au|jp|com\.cn|sa|ca)$"#,
            path: #"^/(meeting/)?join/?$"#
        ),
        ProviderRule(.livestorm, host: #"(^|\.)livestorm\.co$"#, path: #"^/[^/]+/[^/]+"#),
        ProviderRule(.gather, host: #"^(app\.)?gather\.town$"#, path: #"^/(app|invite)/"#),
        // URL formats for Pop and Tuple are assumptions; verify against real invites before relying on them.
        ProviderRule(.pop, host: #"^(www\.)?pop\.com$"#, path: #"^/(j|r)/[A-Za-z0-9_-]+"#),
        ProviderRule(.tuple, host: #"^tuple\.app$"#, path: #"^/c/[A-Za-z0-9_-]+"#),
        ProviderRule(.dialpad, host: #"^meetings\.dialpad\.com$"#, path: #"^/room/[^/]+"#),
    ]
}
