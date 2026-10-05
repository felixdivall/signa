import AppKit
import Foundation

/// Runs one short shell command with administrator rights.
public protocol PrivilegedShell: Sendable {
    /// Throws `IconError.cancelled` if the user declines, and
    /// `IconError.administratorFailed` with the reason if the command fails.
    @MainActor func run(_ command: String, prompt: String) throws
}

/// Asks through the standard macOS password dialog, the same one Finder shows.
public struct AdministratorShell: PrivilegedShell {
    public init() {}

    @MainActor
    public func run(_ command: String, prompt: String) throws {
        func literal(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        let source = "do shell script \(literal(command)) with prompt \(literal(prompt)) with administrator privileges"
        var failure: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw IconError.administratorFailed("The request could not be prepared.")
        }
        script.executeAndReturnError(&failure)
        guard let failure else { return }
        let number = failure[NSAppleScript.errorNumber] as? Int ?? 0
        let message = failure[NSAppleScript.errorMessage] as? String ?? "Unknown error"
        let userCancelled = -128
        if number == userCancelled { throw IconError.cancelled }
        Log.system.error("Administrator request failed (\(number)): \(message, privacy: .public)")
        // The helper reports macOS's own refusal to let an app be modified in these words.
        throw message.contains("permissionDenied") || message.contains("Operation not permitted")
            ? IconError.permissionDenied : IconError.administratorFailed(message)
    }
}

/// Changes the icon of an application that is installed for all users.
///
/// The work is done by a helper program, started with administrator rights
/// after macOS has asked for a password. The helper is Signa's own executable
/// in a mode where it changes one icon and exits, so the change is made with
/// the same system call as everywhere else and Finder hears about it.
public struct AdministratorIconProvider: IconProvider {
    private let shell: any PrivilegedShell
    private let helper: String

    /// - Parameter helper: Path of the program that accepts `--set-icon <icon or -> <application>`.
    public init(shell: any PrivilegedShell = AdministratorShell(), helper: String) {
        self.shell = shell
        self.helper = helper
    }

    public func apply(iconAt iconURL: URL, to applicationURL: URL) async throws -> IconFingerprint {
        try await MainActor.run {
            try shell.run(
                command(icon: iconURL.path, applicationURL),
                prompt: "Signa needs an administrator password to change the icon of \(Self.name(of: applicationURL)).")
            guard let fingerprint = WorkspaceIconProvider.fingerprint(of: applicationURL) else {
                throw IconError.permissionDenied
            }
            return fingerprint
        }
    }

    public func remove(from applicationURL: URL) async throws {
        try await MainActor.run {
            guard WorkspaceIconProvider.fingerprint(of: applicationURL) != nil else { return }
            try shell.run(
                command(icon: "-", applicationURL),
                prompt: "Signa needs an administrator password to restore the icon of \(Self.name(of: applicationURL)).")
        }
    }

    public func current(for applicationURL: URL) async -> IconFingerprint? {
        WorkspaceIconProvider.fingerprint(of: applicationURL)
    }

    private func command(icon: String, _ applicationURL: URL) -> String {
        // The helper runs as administrator but acts for this user, whose permissions apply.
        [helper, "--set-icon", icon, applicationURL.path, "--for-user", String(getuid())]
            .map(Self.quoted).joined(separator: " ")
    }

    private static func quoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func name(of applicationURL: URL) -> String {
        applicationURL.deletingPathExtension().lastPathComponent
    }
}
