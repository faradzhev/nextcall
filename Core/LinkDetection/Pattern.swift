import Foundation

/// Thin `Sendable` wrapper over `NSRegularExpression` (Swift's `Regex` is not `Sendable`).
struct Pattern: Sendable {
    struct Match {
        fileprivate let result: NSTextCheckingResult
        fileprivate let source: NSString

        var range: NSRange { result.range }
        var text: String { source.substring(with: result.range) }

        func group(_ index: Int) -> String? {
            let range = result.range(at: index)
            return range.location == NSNotFound ? nil : source.substring(with: range)
        }
    }

    private let regex: NSRegularExpression

    init(_ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive]) {
        // Patterns are compile-time constants or registry data covered by tests.
        regex = try! NSRegularExpression(pattern: pattern, options: options)
    }

    func hasMatch(in string: String) -> Bool {
        regex.firstMatch(in: string, range: NSRange(location: 0, length: (string as NSString).length)) != nil
    }

    func matches(in string: String) -> [Match] {
        let source = string as NSString
        return regex.matches(in: string, range: NSRange(location: 0, length: source.length))
            .map { Match(result: $0, source: source) }
    }

    func replacing(in string: String, with transform: (Match) -> String) -> String {
        let source = string as NSString
        var output = ""
        var last = 0
        for match in matches(in: string) {
            output += source.substring(with: NSRange(location: last, length: match.range.location - last))
            output += transform(match)
            last = match.range.location + match.range.length
        }
        return output + source.substring(from: last)
    }
}
