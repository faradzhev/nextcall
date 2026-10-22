import Foundation

/// Turns an event field (plain text or HTML) into plain text that is safe to scan for URLs.
enum TextNormalizer {
    private static let scriptsAndStyles = Pattern(#"<(script|style)\b[^>]*>.*?</\1\s*>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let anchor = Pattern(#"<a\b[^>]*?\bhref\s*=\s*(?:"([^"]*)"|'([^']*)')[^>]*>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let lineBreak = Pattern(#"<br\s*/?>|</(p|div|li|tr|h[1-6]|table)>"#)
    /// Only strings that look like real tags: `<https://x>` (Outlook's plain-text link style) must survive.
    private static let tag = Pattern(#"</?[A-Za-z][A-Za-z0-9:-]*(\s[^>]*)?/?>"#, options: [.dotMatchesLineSeparators])
    private static let invisible = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{2060}\u{FEFF}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}")

    static func plainText(from raw: String) -> String {
        var text = raw
        if text.contains("<") {
            text = scriptsAndStyles.replacing(in: text) { _ in " " }
            // Keep each href next to its anchor so redirected or hidden targets are scanned too.
            text = anchor.replacing(in: text) { match in " \(match.group(1) ?? match.group(2) ?? "") " }
            text = lineBreak.replacing(in: text) { _ in "\n" }
            text = tag.replacing(in: text) { _ in "" }
        }
        if text.contains("&") {
            text = HTMLEntities.decode(text)
        }
        text = String(String.UnicodeScalarView(text.unicodeScalars.filter { !invisible.contains($0) }))
        return text.replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}

enum HTMLEntities {
    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
    ]
    private static let entity = Pattern(#"&(#[xX][0-9A-Fa-f]+|#[0-9]+|[A-Za-z][A-Za-z0-9]*);"#, options: [])

    static func decode(_ text: String) -> String {
        entity.replacing(in: text) { match in
            let name = match.group(1) ?? ""
            if let value = named[name.lowercased()] { return value }
            let scalar: UInt32?
            if name.hasPrefix("#x") || name.hasPrefix("#X") {
                scalar = UInt32(name.dropFirst(2), radix: 16)
            } else if name.hasPrefix("#") {
                scalar = UInt32(name.dropFirst())
            } else {
                scalar = nil
            }
            return scalar.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? match.text
        }
    }
}
