import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// A finished macOS icon plus the artwork it came from.
public struct RenderedIcon: Sendable {
    public let icns: Data
    public let source: Data
    public let sourceExtension: String

    public init(icns: Data, source: Data, sourceExtension: String) {
        self.icns = icns
        self.source = source
        self.sourceExtension = sourceExtension
    }
}

/// Turns whatever the user dropped into a proper macOS application icon.
public protocol IconRendering: Sendable {
    func makeIcon(from fileURL: URL) throws -> RenderedIcon
}

public enum IconRenderingError: Error {
    case unreadableImage
}

public struct IconRenderer: IconRendering {
    /// Apple's icon grid: a 1024 pt canvas holding an 824 pt rounded shape.
    private enum Grid {
        static let canvas: CGFloat = 1024
        static let shape = CGRect(x: 100, y: 100, width: 824, height: 824)
        static let cornerRadius: CGFloat = 185.4
    }

    /// Icon family entries, all PNG encoded: (type, pixel size).
    private static let entries: [(type: String, pixels: Int)] = [
        ("icp4", 16), ("icp5", 32), ("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024),
        ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512),
    ]

    public init() {}

    public func makeIcon(from fileURL: URL) throws -> RenderedIcon {
        guard let source = try? Data(contentsOf: fileURL) else {
            throw IconRenderingError.unreadableImage
        }
        let fileExtension = fileURL.pathExtension.lowercased()

        // A ready-made icon file is used exactly as its designer made it.
        if UTType(filenameExtension: fileExtension)?.conforms(to: .icns) == true {
            guard Self.loadImage(from: source) != nil else { throw IconRenderingError.unreadableImage }
            return RenderedIcon(icns: source, source: source, sourceExtension: "icns")
        }

        guard let artwork = Self.loadImage(from: source) else {
            throw IconRenderingError.unreadableImage
        }
        let master = try Self.composeMaster(from: artwork)
        return RenderedIcon(
            icns: try Self.encodeICNS(master: master),
            source: source,
            sourceExtension: fileExtension.isEmpty ? "image" : fileExtension)
    }

    // MARK: - Loading

    /// Decodes the largest image in the data, upright and no larger than needed.
    private static func loadImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        let largest = (0..<count).max { width(of: source, at: $0) < width(of: source, at: $1) } ?? 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, largest, options as CFDictionary)
    }

    private static func width(of source: CGImageSource, at index: Int) -> Int {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        return properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
    }

    // MARK: - Composition

    /// Artwork that already has its own silhouette is kept as drawn. Artwork
    /// that fills its whole rectangle is cut to the standard icon shape.
    static func composeMaster(from artwork: CGImage) throws -> CGImage {
        let context = try makeContext(pixels: Int(Grid.canvas))
        let canvas = CGRect(x: 0, y: 0, width: Grid.canvas, height: Grid.canvas)

        if hasOwnSilhouette(artwork) {
            context.draw(artwork, in: fit(artwork, into: canvas))
        } else {
            let shape = Path(
                roundedRect: Grid.shape, cornerRadius: Grid.cornerRadius, style: .continuous
            ).cgPath

            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: -10), blur: 20,
                color: CGColor(gray: 0, alpha: 0.3))
            context.addPath(shape)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fillPath()
            context.restoreGState()

            context.addPath(shape)
            context.clip()
            context.draw(artwork, in: fill(artwork, over: Grid.shape))
        }

        guard let image = context.makeImage() else { throw IconRenderingError.unreadableImage }
        return image
    }

    /// True when the corners of the image are transparent, which means the
    /// artwork brings its own shape (a finished icon, a logo, a cut-out).
    static func hasOwnSilhouette(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        let side = 32
        guard let context = try? makeContext(pixels: side), let data = context.data else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        let pixels = data.bindMemory(to: UInt8.self, capacity: side * context.bytesPerRow)
        let corners = [(0, 0), (side - 1, 0), (0, side - 1), (side - 1, side - 1)]
        return corners.allSatisfy { x, y in
            pixels[y * context.bytesPerRow + x * 4 + 3] < 26
        }
    }

    private static func fit(_ image: CGImage, into rect: CGRect) -> CGRect {
        let scale = min(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
        return centered(image, scale: scale, in: rect)
    }

    private static func fill(_ image: CGImage, over rect: CGRect) -> CGRect {
        let scale = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
        return centered(image, scale: scale, in: rect)
    }

    private static func centered(_ image: CGImage, scale: CGFloat, in rect: CGRect) -> CGRect {
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        return CGRect(
            x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
            width: size.width, height: size.height)
    }

    private static func makeContext(pixels: Int) throws -> CGContext {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw IconRenderingError.unreadableImage }
        context.interpolationQuality = .high
        return context
    }

    // MARK: - Encoding

    /// Writes the icon family by hand. The container is simple, and doing it
    /// here keeps every Retina size, which ImageIO's own writer leaves out.
    static func encodeICNS(master: CGImage) throws -> Data {
        var pngBySize: [Int: Data] = [:]
        for pixels in Set(entries.map(\.pixels)) {
            pngBySize[pixels] = try png(of: master, pixels: pixels)
        }

        var body = Data()
        for entry in entries {
            guard let png = pngBySize[entry.pixels] else { continue }
            body.append(Data(entry.type.utf8))
            body.append(bigEndian: UInt32(png.count + 8))
            body.append(png)
        }

        var file = Data("icns".utf8)
        file.append(bigEndian: UInt32(body.count + 8))
        file.append(body)
        return file
    }

    private static func png(of master: CGImage, pixels: Int) throws -> Data {
        var image = master
        if pixels != master.width {
            let context = try makeContext(pixels: pixels)
            context.draw(master, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
            guard let scaled = context.makeImage() else { throw IconRenderingError.unreadableImage }
            image = scaled
        }
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data, UTType.png.identifier as CFString, 1, nil)
        else { throw IconRenderingError.unreadableImage }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw IconRenderingError.unreadableImage }
        return data as Data
    }
}

private extension Data {
    mutating func append(bigEndian value: UInt32) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }
}
