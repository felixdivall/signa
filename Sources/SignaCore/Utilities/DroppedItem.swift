import Foundation
import UniformTypeIdentifiers

/// What a file dragged into Signa is good for.
public enum DroppedItem: Equatable, Sendable {
    case application(URL)
    case image(URL)
    case unsupported

    public init(_ url: URL) {
        let type =
            (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
        guard let type else {
            self = .unsupported
            return
        }
        if type.conforms(to: .applicationBundle) {
            self = .application(url)
        } else if type.conforms(to: .image) {
            // Covers .icns, png, jpg, webp, tiff and anything else macOS can decode.
            self = .image(url)
        } else {
            self = .unsupported
        }
    }

    /// The image formats offered in an open panel.
    public static let imageTypes: [UTType] = [.image]
}
