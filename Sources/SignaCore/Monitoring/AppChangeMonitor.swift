import Foundation

/// An application a monitor should keep an eye on.
public struct WatchedApp: Hashable, Sendable {
    public let url: URL
    public let bundleIdentifier: String

    public init(url: URL, bundleIdentifier: String) {
        self.url = url
        self.bundleIdentifier = bundleIdentifier
    }
}

public enum AppChange: Equatable, Sendable {
    /// Something changed inside, or replaced, the application at this location.
    case bundleChanged(URL)
    case applicationLaunched(bundleIdentifier: String)
    /// Changes may have been missed (for example across sleep); check everything.
    case everythingMayHaveChanged
}

/// A source of hints that an application's icon may need attention.
///
/// Monitors are push based: an implementation must not poll, and must cost
/// nothing while no application is changing.
public protocol AppChangeMonitor: Sendable {
    var changes: AsyncStream<AppChange> { get }
    /// Replaces the set of watched applications.
    func watch(_ applications: [WatchedApp])
}
