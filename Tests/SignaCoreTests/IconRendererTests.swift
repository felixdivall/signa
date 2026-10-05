import AppKit
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import SignaCore

@Suite struct IconRendererTests {
    let scratch = try! Scratch()
    let renderer = IconRenderer()

    @Test func producesEveryIconSizeIncludingRetina() throws {
        let file = try scratch.writeImage(TestImage.opaque(), named: "photo.png")
        let icon = try renderer.makeIcon(from: file)

        let source = try #require(CGImageSourceCreateWithData(icon.icns as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == "com.apple.icns")
        var widths: [Int] = []
        for index in 0..<CGImageSourceGetCount(source) {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            widths.append(properties?[kCGImagePropertyPixelWidth] as? Int ?? 0)
        }
        #expect(Set(widths) == [16, 32, 64, 128, 256, 512, 1024])
        #expect(icon.sourceExtension == "png")
    }

    @Test func roundsOffArtworkThatFillsItsRectangle() throws {
        let master = try IconRenderer.composeMaster(from: TestImage.opaque(width: 900, height: 600))
        #expect(master.width == 1024 && master.height == 1024)
        // Outside the icon shape: empty. Inside: the artwork.
        #expect(TestImage.alpha(of: master, x: 4, y: 4) == 0)
        #expect(TestImage.alpha(of: master, x: 110, y: 110) < 255)
        #expect(TestImage.alpha(of: master, x: 512, y: 512) == 255)
        #expect(TestImage.alpha(of: master, x: 512, y: 110) == 255)
    }

    @Test func keepsArtworkThatAlreadyHasAShape() throws {
        #expect(IconRenderer.hasOwnSilhouette(TestImage.cutOut()))
        #expect(!IconRenderer.hasOwnSilhouette(TestImage.opaque()))

        let master = try IconRenderer.composeMaster(from: TestImage.cutOut())
        // The circle still reaches the edge of the canvas: nothing was cropped or inset.
        #expect(TestImage.alpha(of: master, x: 512, y: 3) == 255)
        #expect(TestImage.alpha(of: master, x: 3, y: 3) == 0)
    }

    @Test(arguments: [UTType.jpeg, .tiff, .webP, .png])
    func readsCommonImageFormats(type: UTType) throws {
        // macOS cannot write WebP, so that case is covered by a canned file below.
        guard type != .webP else {
            let webP = Data(
                base64Encoded: "UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==")!
            let file = scratch.url.appendingPathComponent("tiny.webp")
            try webP.write(to: file)
            #expect(throws: Never.self) { try renderer.makeIcon(from: file) }
            return
        }
        let name = "image.\(type.preferredFilenameExtension ?? "img")"
        let file = try scratch.writeImage(TestImage.opaque(), named: name, type: type)
        let icon = try renderer.makeIcon(from: file)
        #expect(NSImage(data: icon.icns)?.isValid == true)
    }

    @Test func usesIconFilesExactlyAsProvided() throws {
        let made = try renderer.makeIcon(from: scratch.writeImage(TestImage.cutOut(), named: "a.png"))
        let file = scratch.url.appendingPathComponent("ready.icns")
        try made.icns.write(to: file)

        let icon = try renderer.makeIcon(from: file)
        #expect(icon.icns == made.icns)
        #expect(icon.sourceExtension == "icns")
    }

    @Test func rejectsFilesThatAreNotImages() throws {
        let file = scratch.url.appendingPathComponent("notes.png")
        try Data("not an image".utf8).write(to: file)
        #expect(throws: IconRenderingError.self) { try renderer.makeIcon(from: file) }
    }
}
