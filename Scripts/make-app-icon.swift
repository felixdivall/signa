// Draws Signa's icon and writes Resources/AppIcon.icns.
//
//   swift Scripts/make-app-icon.swift
//
// The icon is one object in one glaze: a terracotta shell, a recessed square
// where the glaze has pooled to rust, and a diagonal insert where it has
// thinned to apricot. Small sizes are drawn with their own proportions
// rather than scaled down.
import AppKit
import SwiftUI

let N: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

// MARK: - Colour

/// Hue in degrees, saturation and brightness from 0 to 1.
struct HSB {
    var h: CGFloat, s: CGFloat, b: CGFloat

    init(h: CGFloat, s: CGFloat, b: CGFloat) {
        self.h = h
        self.s = s
        self.b = b
    }

    init(_ hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255, g = CGFloat((hex >> 8) & 0xFF) / 255, bl = CGFloat(hex & 0xFF) / 255
        let hi = max(r, g, bl), lo = min(r, g, bl), d = hi - lo
        var hue: CGFloat = 0
        if d > 0 {
            if hi == r { hue = (g - bl) / d } else if hi == g { hue = 2 + (bl - r) / d } else { hue = 4 + (r - g) / d }
            hue *= 60
            if hue < 0 { hue += 360 }
        }
        self.init(h: hue, s: hi == 0 ? 0 : d / hi, b: hi)
    }

    var hex: UInt32 {
        let hh = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let ss = max(0, min(1, s)), bb = max(0, min(1, b))
        let i = Int(hh), f = hh - CGFloat(i)
        let p = bb * (1 - ss), q = bb * (1 - ss * f), t = bb * (1 - ss * (1 - f))
        let (r, g, bl): (CGFloat, CGFloat, CGFloat) =
            [(bb, t, p), (q, bb, p), (p, bb, t), (p, q, bb), (t, p, bb), (bb, p, q)][i % 6]
        return UInt32((r * 255).rounded()) << 16 | UInt32((g * 255).rounded()) << 8 | UInt32((bl * 255).rounded())
    }
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha,
        ])!
}

/// One part of the piece: its colour, and that colour facing toward and away from the light.
struct Glaze {
    let dark: UInt32, base: UInt32, light: UInt32

    init(_ colour: HSB, light: CGFloat = 1.22, dark: CGFloat = 0.68) {
        self.dark = HSB(h: colour.h, s: colour.s * 1.05, b: colour.b * dark).hex
        self.base = colour.hex
        self.light = HSB(h: colour.h, s: colour.s * 0.72, b: min(1, colour.b * light)).hex
    }

    /// A tone from -1 (turned away from the light) to 1 (facing it).
    func tone(_ t: CGFloat) -> CGColor {
        let other = t >= 0 ? light : dark, amount = min(1, abs(t))
        func channel(_ shift: UInt32) -> CGFloat {
            let x = CGFloat((base >> shift) & 0xFF), y = CGFloat((other >> shift) & 0xFF)
            return (x + (y - x) * amount) / 255
        }
        return CGColor(colorSpace: space, components: [channel(16), channel(8), channel(0), 1])!
    }
}

/// Terracotta glaze. Everything else is derived from this one colour.
let terracotta = HSB(0xCC5F34)
let shell = Glaze(terracotta)
/// Pooled in the recess: deeper, a little redder, more saturated. Rust, not brown.
let recess = Glaze(HSB(h: terracotta.h - 5, s: min(1, terracotta.s * 1.22), b: terracotta.b * 0.58), light: 1.35, dark: 0.6)
/// Thinned on the insert: the same hue at a lighter value.
let insert = Glaze(HSB(h: terracotta.h, s: terracotta.s * 0.55, b: terracotta.b + (1 - terracotta.b) * 0.6), light: 1.1, dark: 0.86)
/// Where light catches an edge.
let highlight = HSB(h: terracotta.h, s: terracotta.s * 0.16, b: 1).hex

// MARK: - Drawing helpers

func makeContext(_ pixels: Int) -> CGContext {
    let c = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    return c
}

func rounded(_ side: CGFloat, ratio: CGFloat) -> CGPath {
    Path(
        roundedRect: CGRect(x: (N - side) / 2, y: (N - side) / 2, width: side, height: side),
        cornerRadius: side * ratio, style: .continuous
    ).cgPath
}

/// The outline macOS expects: an 824 pt rounded square on a 1024 pt canvas.
let tilePath = rounded(824, ratio: 0.225)

func shifted(_ path: CGPath, _ dx: CGFloat, _ dy: CGFloat) -> CGPath {
    var t = CGAffineTransform(translationX: dx, y: dy)
    return path.copy(using: &t)!
}

func fill(_ c: CGContext, _ path: CGPath, _ color: CGColor, rule: CGPathFillRule = .winding) {
    c.addPath(path)
    c.setFillColor(color)
    c.fillPath(using: rule)
}

func inside(_ c: CGContext, _ path: CGPath, rule: CGPathFillRule = .winding, _ body: () -> Void) {
    c.saveGState()
    c.addPath(path)
    c.clip(using: rule)
    body()
    c.restoreGState()
}

func linear(_ c: CGContext, _ colors: [CGColor], _ stops: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops)!
    c.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func ring(_ outer: CGPath, _ inner: CGPath) -> CGPath {
    let p = CGMutablePath()
    p.addPath(outer)
    p.addPath(inner)
    return p
}

/// A crescent of light or shade along the edges of a shape that face one way.
func edge(_ c: CGContext, _ path: CGPath, dy: CGFloat, _ color: CGColor) {
    inside(c, path) { fill(c, ring(path, shifted(path, 0, dy)), color, rule: .evenOdd) }
}

/// Everything outside a shape, for casting shadows into it.
func outside(_ path: CGPath) -> CGPath {
    let p = CGMutablePath()
    p.addRect(CGRect(x: -400, y: -400, width: N + 800, height: N + 800))
    p.addPath(path)
    return p
}

/// A face of the piece: lighter toward the upper left, where the light is.
func face(_ c: CGContext, _ path: CGPath, _ glaze: Glaze, contrast: CGFloat) {
    let box = path.boundingBox
    inside(c, path) {
        linear(
            c, [glaze.tone(contrast), glaze.tone(-contrast)], [0, 1], from: CGPoint(x: box.minX, y: box.minY),
            to: CGPoint(x: box.maxX, y: box.maxY))
    }
}

/// Faint flecks, as in a hand-mixed glaze. Fixed seed, so every build draws the same icon.
let flecks: CGImage = {
    let size = 512
    let c = makeContext(size)
    var seed: UInt64 = 0x53_70_65_63
    for y in 0..<size {
        for x in 0..<size {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let v = CGFloat((seed >> 33) & 0xFFFF) / 65535
            c.setFillColor(CGColor(colorSpace: space, components: [v, v, v, 1])!)
            c.fill(CGRect(x: x, y: y, width: 1, height: 1))
        }
    }
    return c.makeImage()!
}()

// MARK: - The icon

/// The proportions of the piece. Small sizes get a larger recess, a wider bevel and firmer shadows.
struct Proportions {
    var side: CGFloat = 500
    var cornerRatio: CGFloat = 0.24
    var depth: CGFloat = 30
    var softness: CGFloat = 1.8
    var rim: CGFloat = 9
    var bevel: CGFloat = 9
    /// The cut sits a little off centre, so the insert covers slightly more than half.
    var cutOffset: CGFloat = 28
    var fleck: CGFloat = 0.07

    static let large = Proportions()
    static let medium = Proportions(side: 520, depth: 26, softness: 1.4, rim: 12, bevel: 14, fleck: 0)
    static let small = Proportions(side: 548, depth: 20, softness: 0.9, rim: 16, bevel: 24, cutOffset: 24, fleck: 0)

    static func forPixels(_ pixels: Int) -> Proportions {
        pixels <= 32 ? .small : pixels <= 64 ? .medium : .large
    }
}

/// Everything on the lower-left side of the cut, widened by `grow` toward the upper right.
func belowCut(_ p: Proportions, grow: CGFloat = 0) -> CGPath {
    let shift = (p.cutOffset + grow) / 2.squareRoot()
    let origin = CGPoint(x: N / 2 + shift, y: N / 2 - shift)
    let reach: CGFloat = 1400, d = 1 / 2.squareRoot()
    let a = CGPoint(x: origin.x - d * reach, y: origin.y - d * reach)
    let b = CGPoint(x: origin.x + d * reach, y: origin.y + d * reach)
    let path = CGMutablePath()
    path.addLines(between: [a, b, CGPoint(x: b.x - d * reach, y: b.y + d * reach), CGPoint(x: a.x - d * reach, y: a.y + d * reach)])
    path.closeSubpath()
    return path
}

func drawIcon(_ c: CGContext, _ p: Proportions) {
    // The shell.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: rgb(0x000000, 0.32))
    fill(c, tilePath, shell.tone(-0.45))
    c.restoreGState()
    c.addPath(tilePath)
    c.clip()
    linear(c, [shell.tone(0.25), shell.tone(-0.21)], [0, 1], from: CGPoint(x: 0, y: 100), to: CGPoint(x: 0, y: 924))
    let pool = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.1), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    let lamp = CGPoint(x: 340, y: 200)
    c.drawRadialGradient(pool, startCenter: lamp, startRadius: 0, endCenter: lamp, endRadius: 700, options: [])
    edge(c, tilePath, dy: 4, rgb(0xFFFFFF, 0.28))
    edge(c, tilePath, dy: -4, rgb(0x000000, 0.2))
    c.addPath(tilePath)
    c.setStrokeColor(rgb(0xFFFFFF, 0.12))
    c.setLineWidth(4)
    c.strokePath()

    let mouth = rounded(p.side + p.rim * 2, ratio: p.cornerRatio), floor = rounded(p.side, ratio: p.cornerRatio)

    // The sloped edge of the recess: shaded at the upper left, lit at the lower right.
    let box = mouth.boundingBox
    let corner = CGPoint(x: box.minX, y: box.minY), opposite = CGPoint(x: box.maxX, y: box.maxY)
    inside(c, ring(mouth, floor), rule: .evenOdd) {
        linear(c, [shell.tone(-0.75), shell.tone(0.05), shell.tone(0.8)], [0.12, 0.5, 0.88], from: corner, to: opposite)
        linear(c, [rgb(highlight, 0), rgb(highlight, 0.5)], [0.55, 1], from: corner, to: opposite)
    }

    // The floor of the recess, in shadow under its upper wall.
    face(c, floor, recess, contrast: 0.1)
    inside(c, floor) {
        c.setShadow(offset: CGSize(width: p.depth * 0.4, height: -p.depth), blur: p.depth * p.softness, color: rgb(0x000000, 0.5))
        fill(c, outside(floor), rgb(0x000000), rule: .evenOdd)
    }

    // The insert, flush with the shell and glazed.
    let half = belowCut(p)
    c.saveGState()
    c.addPath(floor)
    c.clip()
    c.saveGState()
    c.setShadow(offset: CGSize(width: 3, height: -4), blur: 16 * p.softness / 1.5, color: rgb(0x000000, 0.4))
    fill(c, half, rgb(0x000000))
    c.restoreGState()
    c.addPath(half)
    c.clip()
    face(c, floor, insert, contrast: 0.26)
    let sheen = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.3), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    let glint = CGPoint(x: N / 2 - p.side * 0.26, y: N / 2 + p.side * 0.08)
    c.drawRadialGradient(sheen, startCenter: glint, startRadius: 0, endCenter: glint, endRadius: p.side * 0.42, options: [])
    // The bevel along the cut catches the light.
    inside(c, ring(half, belowCut(p, grow: -p.bevel * 2.squareRoot())), rule: .evenOdd) {
        fill(c, floor, insert.tone(0.55))
        fill(c, floor, rgb(highlight, 0.45))
    }
    // A hairline where the insert meets the shell.
    c.addPath(floor)
    c.setStrokeColor(rgb(0x000000, 0.225))
    c.setLineWidth(3)
    c.strokePath()
    c.restoreGState()

    // Light on the lower lip of the recess.
    let lowered = shifted(mouth, 0, 3)
    inside(c, ring(lowered, mouth), rule: .evenOdd) { fill(c, lowered, rgb(highlight, 0.3)) }

    if p.fleck > 0 {
        c.saveGState()
        c.setBlendMode(.softLight)
        c.setAlpha(p.fleck)
        c.draw(flecks, in: CGRect(x: 100, y: 100, width: 824, height: 824))
        c.restoreGState()
    }
}

/// Draws the icon for one pixel size, using the proportions meant for it.
func render(pixels: Int) -> CGImage {
    let master = makeContext(Int(N))
    master.translateBy(x: 0, y: N)
    master.scaleBy(x: 1, y: -1)
    drawIcon(master, .forPixels(pixels))
    guard pixels != Int(N) else { return master.makeImage()! }
    let c = makeContext(pixels)
    c.draw(master.makeImage()!, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return c.makeImage()!
}

// MARK: - Export

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Signa.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let png = NSBitmapImageRep(cgImage: render(pixels: points * scale)).representation(using: .png, properties: [:])!
        try! png.write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
