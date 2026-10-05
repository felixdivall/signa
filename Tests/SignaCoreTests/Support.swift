import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@testable import SignaCore

/// A scratch folder that cleans up after itself.
final class Scratch {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SignaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// Creates the smallest thing macOS and Signa accept as an application.
    @discardableResult
    func makeApp(named name: String = "Sample", identifier: String = "test.signa.sample", in folder: String = "Apps")
        throws -> URL
    {
        let app = url.appendingPathComponent("\(folder)/\(name).app", isDirectory: true)
        let macOS = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": identifier, "CFBundleExecutable": name]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        try Data("#!/bin/sh\n".utf8).write(to: macOS.appendingPathComponent(name))
        return app
    }

    func writeImage(_ image: CGImage, named name: String, type: UTType = .png) throws -> URL {
        let file = url.appendingPathComponent(name)
        let destination = CGImageDestinationCreateWithURL(file as CFURL, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return file
    }
}

enum TestImage {
    /// A fully opaque rectangle, like a photo or a wallpaper.
    static func opaque(width: Int = 600, height: Int = 600) -> CGImage {
        let context = makeContext(width: width, height: height, alpha: .noneSkipLast)
        context.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    /// A circle on a transparent background, like a finished icon or a logo.
    static func cutOut(side: Int = 512) -> CGImage {
        let context = makeContext(width: side, height: side, alpha: .premultipliedLast)
        context.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 1))
        context.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
        return context.makeImage()!
    }

    private static func makeContext(width: Int, height: Int, alpha: CGImageAlphaInfo) -> CGContext {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue)!
    }

    /// Alpha (0...255) of one pixel, with (0, 0) at the top left.
    static func alpha(of image: CGImage, x: Int, y: Int) -> UInt8 {
        let context = makeContext(width: image.width, height: image.height, alpha: .premultipliedLast)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = context.data!.bindMemory(to: UInt8.self, capacity: image.height * context.bytesPerRow)
        return pixels[y * context.bytesPerRow + x * 4 + 3]
    }
}

// MARK: - Fakes

/// Stands in for the file system: remembers which icon each application has.
final class FakeIconProvider: IconProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var installed: [String: IconFingerprint] = [:]
    private var failure: IconError?
    private(set) var applyCount = 0

    func apply(iconAt iconURL: URL, to applicationURL: URL) async throws -> IconFingerprint {
        try lock.withLock {
            if let failure { throw failure }
            applyCount += 1
            let fingerprint = IconFingerprint(rawValue: "\(iconURL.path)#\(applyCount)")
            installed[applicationURL.path] = fingerprint
            return fingerprint
        }
    }

    func remove(from applicationURL: URL) async throws {
        try lock.withLock {
            if let failure { throw failure }
            installed[applicationURL.path] = nil
        }
    }

    func current(for applicationURL: URL) async -> IconFingerprint? {
        lock.withLock { installed[applicationURL.path] }
    }

    /// What an application update does to a custom icon.
    func simulateUpdate(of applicationURL: URL) {
        lock.withLock { installed[applicationURL.path] = nil }
    }

    func fail(with error: IconError?) {
        lock.withLock { failure = error }
    }
}

final class FakeInspector: AppInspecting, @unchecked Sendable {
    private let lock = NSLock()
    private var infos: [String: AppInfo] = [:]
    private var levels: [String: AppAccess] = [:]

    func install(_ info: AppInfo, at url: URL, access: AppAccess = .open) {
        lock.withLock {
            infos[url.path] = info
            levels[url.path] = access
        }
    }

    func uninstall(at url: URL) {
        lock.withLock { infos[url.path] = nil }
    }

    func info(at applicationURL: URL) -> AppInfo? {
        lock.withLock { infos[applicationURL.path] }
    }

    func access(to applicationURL: URL) -> AppAccess {
        lock.withLock { levels[applicationURL.path] ?? .open }
    }
}

/// Runs the command as the current user, so the administrator path can be exercised on throwaway applications.
struct UnprivilegedShell: PrivilegedShell {
    @MainActor func run(_ command: String, prompt: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 { throw IconError.administratorFailed("exit \(process.terminationStatus)") }
    }
}

/// Stands in for the user at the password prompt.
struct DecliningShell: PrivilegedShell {
    @MainActor func run(_ command: String, prompt: String) throws { throw IconError.cancelled }
}

final class MemoryLibraryStore: LibraryStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var saved: [ManagedApp] = []

    func load() throws -> [ManagedApp] { lock.withLock { saved } }
    func save(_ apps: [ManagedApp]) throws { lock.withLock { saved = apps } }
}

final class ManualMonitor: AppChangeMonitor, @unchecked Sendable {
    let changes: AsyncStream<AppChange>
    private let continuation: AsyncStream<AppChange>.Continuation
    private let lock = NSLock()
    private var applications: [WatchedApp] = []

    init() {
        (changes, continuation) = AsyncStream.makeStream()
    }

    var watched: [WatchedApp] { lock.withLock { applications } }

    func watch(_ applications: [WatchedApp]) {
        lock.withLock { self.applications = applications }
    }

    func send(_ change: AppChange) {
        continuation.yield(change)
    }
}

final class RecordingLoginItem: LoginItemControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = false

    var isEnabled: Bool { lock.withLock { enabled } }

    func setEnabled(_ enabled: Bool) {
        lock.withLock { self.enabled = enabled }
    }
}

final class RecordingNotifier: UserNotifying, @unchecked Sendable {
    private let lock = NSLock()
    private var sent: [String] = []

    var titles: [String] { lock.withLock { sent } }

    func notify(title: String, body: String) {
        lock.withLock { sent.append(title) }
    }
}

/// Waits for something that happens asynchronously, without fixed sleeps.
func eventually(
    within timeout: Duration = .seconds(10), _ condition: @MainActor () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return await condition()
}
