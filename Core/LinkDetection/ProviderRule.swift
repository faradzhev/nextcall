import Foundation

/// How much of the original query string survives cleaning.
public enum QueryPolicy: Sendable, Equatable {
    case all
    case only([String])
}

/// How to derive the native-app URL for a cleaned link.
public enum NativeScheme: Sendable, Equatable {
    case none
    case zoom
    case teams
    case webex
    case slack
    case discord
    case jitsi
}

/// One provider rule. The registry is a list of these, so adding or fixing a provider is a data change.
public struct ProviderRule: Sendable, Equatable {
    public let provider: Provider
    /// Case-insensitive regex matched against the lowercased host.
    public let hostPattern: String
    /// Case-insensitive regex matched against the (decoded) URL path.
    public let pathPattern: String
    public let query: QueryPolicy
    public let keepFragment: Bool
    public let native: NativeScheme

    public init(
        _ provider: Provider,
        host: String,
        path: String,
        query: QueryPolicy = .all,
        keepFragment: Bool = false,
        native: NativeScheme = .none
    ) {
        self.provider = provider
        hostPattern = host
        pathPattern = path
        self.query = query
        self.keepFragment = keepFragment
        self.native = native
    }
}
