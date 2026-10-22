import Foundation

/// Finds http(s) URLs in free text with NSDataDetector plus a regex fallback.
/// `NSDataDetector` is not documented as thread-safe, so access is serialized.
final class LinkExtractor: @unchecked Sendable {
    private let lock = NSLock()
    private let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private static let fallback = Pattern(#"https?://[^\s<>"'\uFFFC]+"#)
    private static let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?)]}>'\"”’")

    private struct Candidate {
        let range: Range<Int>
        let url: URL
    }

    /// URLs in document order. Overlapping detector and regex hits keep the longer one.
    func urls(in rawText: String) -> [URL] {
        let text = TextNormalizer.plainText(from: rawText)
        guard text.contains(".") else { return [] }

        var candidates = detectorCandidates(in: text) + fallbackCandidates(in: text)
        candidates.sort { $0.range.lowerBound != $1.range.lowerBound ? $0.range.lowerBound < $1.range.lowerBound : $0.range.count > $1.range.count }

        var result: [URL] = []
        var coveredUntil = -1
        for candidate in candidates where candidate.range.lowerBound >= coveredUntil {
            guard let scheme = candidate.url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { continue }
            result.append(candidate.url)
            coveredUntil = candidate.range.upperBound
        }
        return result
    }

    private func detectorCandidates(in text: String) -> [Candidate] {
        let nsText = text as NSString
        let matches = lock.withLock {
            detector?.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) ?? []
        }
        return matches.compactMap { match in
            guard let url = match.url else { return nil }
            return Candidate(range: match.range.location..<(match.range.location + match.range.length), url: url)
        }
    }

    private func fallbackCandidates(in text: String) -> [Candidate] {
        Self.fallback.matches(in: text).compactMap { match in
            var raw = match.text
            while let last = raw.unicodeScalars.last, Self.trailingPunctuation.contains(last) {
                raw.removeLast()
            }
            guard let url = URL.lenient(raw) else { return nil }
            let lower = match.range.location
            return Candidate(range: lower..<(lower + (raw as NSString).length), url: url)
        }
    }
}
