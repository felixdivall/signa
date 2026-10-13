// Makes Resources/AppIcon.icns from the icon artwork, Resources/Signa.png.
//
//   swift Scripts/make-app-icon.swift
//
// The artwork is a painting of the icon on a white ground, shadow included,
// so it cannot be used as it is: macOS wants the tile alone on a transparent
// canvas and draws icons at sizes down to 16 pixels. This finds the tile in
// the painting, fits it to the frame macOS expects (an 824 pt rounded square
// on a 1024 pt canvas), cuts it out along that outline, gives it the same
// shadow as the icons around it in the Dock, and writes every size.
import AppKit
import SwiftUI

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("Resources/Signa.png")
let space = CGColorSpace(name: CGColorSpace.sRGB)!

let art = NSBitmapImageRep(data: try! Data(contentsOf: source))!.cgImage!

// MARK: - Finding the tile

/// The tile is coloured and its ground is neutral: white, or grey where the
/// painted shadow falls. Red well above blue tells them apart.
func tileBounds(of image: CGImage) -> CGRect {
    let w = image.width, h = image.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    let c = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var minX = w, maxX = -1, minY = h, maxY = -1
    for y in 0..<h {
        for x in 0..<w {
            let i = (y * w + x) * 4
            if Int(pixels[i]) - Int(pixels[i + 2]) > 40 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
    }
    precondition(maxX > minX && maxY > minY, "No tile found in \(source.lastPathComponent)")
    // Rows in the buffer run top to bottom, which is how cropping counts them too.
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

let bounds = tileBounds(of: art)
let tileArt = art.cropping(to: bounds)!

// MARK: - The icon

/// The outline macOS expects: an 824 pt rounded square on a 1024 pt canvas.
/// The corner ratio is measured from the painting, whose corners are rounder
/// than Apple's template (0.225): with that, the white ground shows through
/// at every corner. 0.26 follows the painted corners to within a quarter of a
/// point all the way round.
let frame = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = RoundedRectangle(cornerRadius: 824 * 0.26, style: .continuous)
    .path(in: frame.insetBy(dx: 1.5, dy: 1.5)).cgPath   // inset: the painting's edge pixels are half ground

func render() -> CGImage {
    let n = 1024
    let c = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high

    // The same shadow as before, and as the system's own icons: soft, below.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -12), blur: 26,
                color: CGColor(colorSpace: space, components: [0, 0, 0, 0.32])!)
    c.beginTransparencyLayer(auxiliaryInfo: nil)
    c.addPath(tilePath)
    c.clip()
    // The painted tile is not quite square, so it is fitted to the frame
    // rather than letterboxed in it.
    c.draw(tileArt, in: frame)
    c.endTransparencyLayer()
    c.restoreGState()
    return c.makeImage()!
}

let master = render()

// MARK: - Every size

func scaled(_ image: CGImage, to pixels: Int) -> Data {
    let c = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    c.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Signa.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try! scaled(master, to: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try! scaled(master, to: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

if CommandLine.arguments.count > 1 {
    // A preview of the 1024 px icon, for checking the cut without building.
    try! scaled(master, to: 1024).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns (tile found at \(bounds))" : "iconutil failed")
