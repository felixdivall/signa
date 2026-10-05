import AppKit
import Foundation
import os

/// Two inexpensive safety nets on top of file watching: a managed application
/// starting up (updaters relaunch what they update), and the Mac waking.
public final class WorkspaceEventMonitor: AppChangeMonitor, @unchecked Sendable {
    public let changes: AsyncStream<AppChange>

    private let continuation: AsyncStream<AppChange>.Continuation
    private let watched = OSAllocatedUnfairLock<Set<String>>(initialState: [])
    // Written once in `init`, read once in `deinit`.
    private var observers: [any NSObjectProtocol] = []

    public init() {
        (changes, continuation) = AsyncStream.makeStream()
        let center = NSWorkspace.shared.notificationCenter
        let continuation = continuation
        let watched = watched

        let launch = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: nil
        ) { notification in
            let application =
                notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let identifier = application?.bundleIdentifier,
                watched.withLock({ $0.contains(identifier) })
            else { return }
            continuation.yield(.applicationLaunched(bundleIdentifier: identifier))
        }
        let wake = center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: nil
        ) { _ in
            guard watched.withLock({ !$0.isEmpty }) else { return }
            continuation.yield(.everythingMayHaveChanged)
        }
        observers = [launch, wake]
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach(center.removeObserver)
        continuation.finish()
    }

    public func watch(_ applications: [WatchedApp]) {
        watched.withLock { $0 = Set(applications.map(\.bundleIdentifier)) }
    }
}
