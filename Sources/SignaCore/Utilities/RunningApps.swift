import AppKit
import Foundation

/// Whether an application is open right now, and since when.
public enum RunningAppState: Equatable, Sendable {
    case notRunning
    /// The launch time is unknown for a few applications that macOS did not start itself.
    case running(since: Date?)
}

public protocol RunningAppChecking: Sendable {
    @MainActor func state(ofApplicationAt url: URL) -> RunningAppState
}

public struct WorkspaceRunningApps: RunningAppChecking {
    public init() {}

    @MainActor
    public func state(ofApplicationAt url: URL) -> RunningAppState {
        let path = url.resolvingSymlinksInPath().path
        let running = NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.resolvingSymlinksInPath().path == path
        }
        guard let running else { return .notRunning }
        return .running(since: running.launchDate)
    }
}
