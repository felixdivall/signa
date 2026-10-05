import Foundation

/// A custom icon kept in Signa's own storage.
///
/// Assets are immutable and referenced by identifier, so several applications
/// (and, later, packs, history entries or appearance variants) can point at
/// the same one without copying it.
public enum IconAsset {
    public struct ID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public var description: String { rawValue }
    }
}

/// Identifies the exact icon data installed on an application, so Signa can
/// tell "still mine" apart from "replaced by an update" without rewriting it.
public struct IconFingerprint: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
