import CoreServices
import Foundation

/// Watches the managed application bundles, and only those, through FSEvents.
///
/// The kernel delivers events when a bundle is replaced, recreated or modified
/// in place. Between events this object does no work at all.
public final class FSEventsMonitor: AppChangeMonitor, @unchecked Sendable {
    public let changes: AsyncStream<AppChange>

    private let continuation: AsyncStream<AppChange>.Continuation
    private let queue = DispatchQueue(label: "com.felixdivall.signa.fsevents")
    // Only touched on `queue`.
    private var stream: FSEventStreamRef?
    private var roots: [String: URL] = [:]

    public init() {
        (changes, continuation) = AsyncStream.makeStream()
    }

    deinit {
        stopStream()
        continuation.finish()
    }

    public func watch(_ applications: [WatchedApp]) {
        queue.async { [self] in
            var newRoots: [String: URL] = [:]
            for application in applications {
                newRoots[Self.realPath(of: application.url)] = application.url
            }
            guard Set(newRoots.keys) != Set(roots.keys) else { return }
            stopStream()
            roots = newRoots
            startStream()
        }
    }

    private func startStream() {
        guard !roots.isEmpty else { return }
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil)
        let flags =
            kFSEventStreamCreateFlagUseCFTypes
            | kFSEventStreamCreateFlagFileEvents  // changes inside a bundle
            | kFSEventStreamCreateFlagWatchRoot  // the bundle itself being swapped
            | kFSEventStreamCreateFlagIgnoreSelf  // not our own icon writes
        guard
            let stream = FSEventStreamCreate(
                nil, Self.callback, &context, Array(roots.keys) as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0, UInt32(flags))
        else { return }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    private func stopStream() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private static let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
        guard let info, let paths = unsafeBitCast(paths, to: NSArray.self) as? [String] else { return }
        let monitor = Unmanaged<FSEventsMonitor>.fromOpaque(info).takeUnretainedValue()
        monitor.handle(paths: paths, flags: Array(UnsafeBufferPointer(start: flags, count: count)))
    }

    private func handle(paths: [String], flags: [FSEventStreamEventFlags]) {
        let lostEvents = UInt32(
            kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped
                | kFSEventStreamEventFlagKernelDropped)

        var changed: Set<String> = []
        for (path, flag) in zip(paths, flags) {
            if flag & lostEvents != 0 {
                continuation.yield(.everythingMayHaveChanged)
                return
            }
            if let root = roots.keys.first(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                changed.insert(root)
            }
        }
        for root in changed {
            if let url = roots[root] { continuation.yield(.bundleChanged(url)) }
        }
    }

    /// FSEvents reports fully resolved paths. The bundle itself may be absent
    /// in the middle of an update, so resolve its folder instead.
    private static func realPath(of url: URL) -> String {
        let folder = url.deletingLastPathComponent().path
        guard let resolved = realpath(folder, nil) else { return url.path }
        defer { free(resolved) }
        return String(cString: resolved) + "/" + url.lastPathComponent
    }
}
