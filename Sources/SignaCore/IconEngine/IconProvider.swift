import Foundation

/// How icons get onto applications. Nothing outside the icon engine knows or
/// cares which mechanism is used, so it can be swapped (for example for a
/// privileged helper) without touching the rest of Signa.
public protocol IconProvider: Sendable {
    /// Installs the icon and returns a fingerprint of what was written.
    func apply(iconAt iconURL: URL, to applicationURL: URL) async throws -> IconFingerprint
    /// Removes any custom icon so the application shows its own again.
    func remove(from applicationURL: URL) async throws
    /// The fingerprint of the custom icon currently installed, if any.
    func current(for applicationURL: URL) async -> IconFingerprint?
}

/// What it takes to change an application's icon.
public enum AppAccess: Equatable, Sendable {
    /// The user owns it; nothing extra is needed.
    case open
    /// It is installed for all users, so macOS wants an administrator password.
    case administrator
    /// It is part of macOS and cannot be changed by anyone.
    case sealed
}

public enum IconError: Error, Equatable {
    /// There is no application at that location.
    case applicationNotFound
    /// The application is part of macOS and cannot be changed.
    case locked
    /// The application is installed for all users; an administrator has to approve the change.
    case needsAdministrator
    /// The user dismissed the password prompt.
    case cancelled
    /// The administrator request ran but did not succeed. Carries what macOS reported.
    case administratorFailed(String)
    /// macOS refused the change; the user has to allow Signa to manage apps.
    case permissionDenied
    case unreadableIcon
}
