// Draws the backdrop of the installer disk image and writes
// Resources/dmg-background.tiff, at 1x and 2x in one file so Finder picks
// the right one for the display.
//
//   swift Scripts/make-dmg-background.swift
//
// The picture is sized to the Finder window Scripts/package-dmg.sh opens, and
// the arrow sits between where that script places the two icons. Change one,
// change the other.
import AppKit

let size = CGSize(width: 600, height: 380)   // points; must match package-dmg.sh
let iconY: CGFloat = 158                     // centre line of the two icons
let appX: CGFloat = 150, applicationsX: CGFloat = 450
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [
        CGFloat((hex >> 16) & 0xff) / 255, CGFloat((hex >> 8) & 0xff) / 255, CGFloat(hex & 0xff) / 255, alpha])!
}

func draw(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.scaleBy(x: scale, y: scale)
    // Finder's origin is the top left; flip so the numbers above read that way.
    cg.translateBy(x: 0, y: size.height)
    cg.scaleBy(x: 1, y: -1)

    // Warm paper, a touch darker towards the bottom, the way a desk is lit.
    let paper = CGGradient(colorsSpace: space, colors: [rgb(0xF6F0E8), rgb(0xECE3D8)] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(paper, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

    // The glaze's warmth, pooled faintly behind the app. Enough to tie the
    // picture to the icon, not enough to read as a spotlight.
    let glow = CGGradient(colorsSpace: space, colors: [rgb(0xCC5F34, 0.16), rgb(0xCC5F34, 0)] as CFArray, locations: [0, 1])!
    cg.drawRadialGradient(glow, startCenter: CGPoint(x: appX, y: iconY), startRadius: 0,
                          endCenter: CGPoint(x: appX, y: iconY), endRadius: 190, options: [])

    // One arrow, from the app towards Applications: a line with an open head.
    let arrowColor = rgb(0x9A6650, 0.75)
    let y = iconY
    let x0: CGFloat = 262, x1: CGFloat = 338, head: CGFloat = 11
    cg.setStrokeColor(arrowColor)
    cg.setLineWidth(2.5)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    cg.move(to: CGPoint(x: x0, y: y)); cg.addLine(to: CGPoint(x: x1, y: y))
    cg.move(to: CGPoint(x: x1 - head, y: y - head)); cg.addLine(to: CGPoint(x: x1, y: y)); cg.addLine(to: CGPoint(x: x1 - head, y: y + head))
    cg.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    rep.size = size   // the point size, set after drawing: this is what makes the 2x rep "2x"
    return rep
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/dmg-background.tiff")
let image = NSImage(size: size)
image.addRepresentation(draw(scale: 1))
image.addRepresentation(draw(scale: 2))
try! image.tiffRepresentation!.write(to: out)
print("wrote \(out.path)")
