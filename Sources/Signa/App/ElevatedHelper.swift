import AppKit
import SignaCore

/// A second way to start Signa: not as an app, but to change one icon and exit.
///
/// The administrator path runs this with root rights:
///
///     Signa --set-icon <icon file, or - to remove> <application> --for-user <user id>
///
/// macOS only lets a process modify a protected app when the permission the
/// user gave Signa applies to that process. A command started by the system's
/// password service is attributed to that service, not to Signa. So the helper
/// starts itself once more, standing on its own, and that copy is judged as
/// what it is: Signa.
///
/// The permission itself is stored for the user who granted it. A process
/// started by the password service belongs to no login session, so before
/// touching anything the helper records which user it is acting for.
enum ElevatedHelper {
    private static let command = "--set-icon"
    private static let standalone = "--standalone"
    private static let forUser = "--for-user"

    static var isRequested: Bool {
        CommandLine.arguments.count >= 4 && CommandLine.arguments[1] == command
    }

    /// Does the work and ends the process. Never returns.
    @MainActor
    static func run() -> Never {
        let arguments = CommandLine.arguments
        let attribution = actOnBehalfOfUser(arguments)
        guard arguments.contains(standalone) else { exit(restartStandingAlone(arguments)) }

        let icon = arguments[2], application = URL(fileURLWithPath: arguments[3], isDirectory: true)
        Task {
            do {
                let provider = WorkspaceIconProvider()
                if icon == "-" {
                    try await provider.remove(from: application)
                } else {
                    _ = try await provider.apply(iconAt: URL(fileURLWithPath: icon), to: application)
                }
                exit(0)
            } catch {
                FileHandle.standardError.write(
                    Data("Signa could not change the icon: \(error) [\(attribution)]\n".utf8))
                exit(1)
            }
        }
        RunLoop.main.run()
        exit(1)
    }

    /// When running as administrator, marks this process as acting for the given user,
    /// so macOS looks up the permission that user granted. Returns a note for diagnostics.
    private static func actOnBehalfOfUser(_ arguments: [String]) -> String {
        guard getuid() == 0 else { return "running as the user" }
        guard let index = arguments.firstIndex(of: forUser), arguments.indices.contains(index + 1),
            var user = uid_t(arguments[index + 1])
        else { return "administrator, no user given" }
        typealias SetAuditUser = @convention(c) (UnsafePointer<uid_t>) -> Int32
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "setauid") else {
            return "administrator, cannot set the acting user"
        }
        let result = unsafeBitCast(symbol, to: SetAuditUser.self)(&user)
        return result == 0
            ? "administrator acting for user \(user)"
            : "administrator, setting the acting user failed (\(String(cString: strerror(errno))))"
    }

    /// Starts this program again as a process that answers for itself, and waits for it.
    private static func restartStandingAlone(_ arguments: [String]) -> Int32 {
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // Not in the public headers, but long established: browsers and editors use it for the same reason.
        typealias Disclaim = @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>, Int32) -> Int32
        if let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_spawnattrs_setdisclaim") {
            _ = unsafeBitCast(symbol, to: Disclaim.self)(&attributes, 1)
        }

        let path = Bundle.main.executablePath ?? arguments[0]
        var argv: [UnsafeMutablePointer<CChar>?] = (arguments + [standalone]).map { strdup($0) }
        argv.append(nil)
        defer { argv.forEach { free($0) } }

        var pid: pid_t = 0
        guard posix_spawn(&pid, path, nil, &attributes, argv, environ) == 0 else { return 1 }
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        return (status & 0x7F) == 0 ? (status >> 8) & 0xFF : 1
    }
}
