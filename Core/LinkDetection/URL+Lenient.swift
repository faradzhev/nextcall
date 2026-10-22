import Foundation

extension URL {
    /// Parses a URL string found in free text.
    ///
    /// `URL(string:)` re-encodes the whole string when it contains an invalid character, which turns
    /// existing escapes like `%20` into `%2520` and corrupts the link. So the strict parse is tried first
    /// and, only if it fails, invalid characters (raw braces or quotes in a query) are escaped on their own.
    static func lenient(_ string: String) -> URL? {
        if let url = URL(string: string, encodingInvalidCharacters: false) { return url }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.formUnion(CharacterSet(charactersIn: "#%"))
        return string.addingPercentEncoding(withAllowedCharacters: allowed)
            .flatMap { URL(string: $0, encodingInvalidCharacters: false) }
    }
}
