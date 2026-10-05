// Signa icon exploration, round three: one object, the clasp, in twenty variations.
// Two hooks locked into each other that together read as an S.
//
//   swiftc -O Design/IconConcepts/clasp.swift -o /tmp/signa-clasp && /tmp/signa-clasp Design/IconConcepts/out
import AppKit
import SwiftUI

let N: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let center = CGPoint(x: N / 2, y: N / 2)

// MARK: - Toolkit

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha,
        ])!
}

func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> CGColor {
    func channel(_ shift: UInt32) -> CGFloat {
        let x = CGFloat((a >> shift) & 0xFF), y = CGFloat((b >> shift) & 0xFF)
        return (x + (y - x) * t) / 255
    }
    return CGColor(colorSpace: space, components: [channel(16), channel(8), channel(0), 1])!
}

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    return c
}

let tilePath = Path(
    roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerRadius: 185.4, style: .continuous
).cgPath

func shifted(_ path: CGPath, _ dx: CGFloat, _ dy: CGFloat) -> CGPath {
    var t = CGAffineTransform(translationX: dx, y: dy)
    return path.copy(using: &t)!
}

func fill(_ c: CGContext, _ path: CGPath, _ color: CGColor, rule: CGPathFillRule = .winding) {
    c.addPath(path)
    c.setFillColor(color)
    c.fillPath(using: rule)
}

func gradient(_ c: CGContext, _ colors: [CGColor], _ stops: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops)!
    c.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// Runs `body` with drawing limited to the inside of `path`.
func inside(_ c: CGContext, _ path: CGPath, _ body: () -> Void) {
    c.saveGState()
    c.addPath(path)
    c.clip()
    body()
    c.restoreGState()
}

/// A crescent of light or shade along the edges of a shape that face one way.
func edge(_ c: CGContext, _ path: CGPath, dx: CGFloat = 0, dy: CGFloat, _ color: CGColor) {
    inside(c, path) {
        let p = CGMutablePath()
        p.addPath(path)
        p.addPath(shifted(path, dx, dy))
        fill(c, p, color, rule: .evenOdd)
    }
}

/// The tile: tonal body, a light catching the top edge, a fine rim so dark
/// tiles keep their outline on a dark Dock. Leaves the context clipped to it.
func tile(_ c: CGContext, top: UInt32, bottom: UInt32, edgeLight: CGFloat = 0.18, rim: CGFloat = 0.1, glow: CGFloat = 0.1) {
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: rgb(0x000000, 0.32))
    fill(c, tilePath, rgb(bottom))
    c.restoreGState()
    c.addPath(tilePath)
    c.clip()
    gradient(c, [rgb(top), rgb(bottom)], [0, 1], from: CGPoint(x: 0, y: 100), to: CGPoint(x: 0, y: 924))
    // A soft pool of light from the upper left.
    let pool = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, glow), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(
        pool, startCenter: CGPoint(x: 360, y: 220), startRadius: 0, endCenter: CGPoint(x: 360, y: 220),
        endRadius: 640, options: [])
    edge(c, tilePath, dy: 4, rgb(0xFFFFFF, edgeLight))
    edge(c, tilePath, dy: -4, rgb(0x000000, 0.18))
    c.addPath(tilePath)
    c.setStrokeColor(rgb(0xFFFFFF, rim))
    c.setLineWidth(4)
    c.strokePath()
}

// MARK: - The object

struct Form {
    var left: CGFloat = 300, right: CGFloat = 590, top: CGFloat = 262, bottom: CGFloat = 572
    var radius: CGFloat = 96, width: CGFloat = 84
    /// Where the outer arm (far from the partner) and the inner arm (inside the partner) end.
    var outerEnd: CGFloat? = nil, innerEnd: CGFloat? = nil
    var cap: CGLineCap = .butt
    var rotation: CGFloat = 0, scale: CGFloat = 1
}

/// Centre lines of the two hooks. The lower one is the upper one turned half way round.
func hooks(_ f: Form) -> (upper: CGPath, lower: CGPath) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: f.outerEnd ?? f.right, y: f.top))
    p.addLine(to: CGPoint(x: f.left + f.radius, y: f.top))
    p.addArc(tangent1End: CGPoint(x: f.left, y: f.top), tangent2End: CGPoint(x: f.left, y: f.top + f.radius), radius: f.radius)
    p.addLine(to: CGPoint(x: f.left, y: f.bottom - f.radius))
    p.addArc(
        tangent1End: CGPoint(x: f.left, y: f.bottom), tangent2End: CGPoint(x: f.left + f.radius, y: f.bottom), radius: f.radius)
    p.addLine(to: CGPoint(x: f.innerEnd ?? f.right, y: f.bottom))
    var place = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: f.rotation).scaledBy(x: f.scale, y: f.scale)
        .translatedBy(x: -center.x, y: -center.y)
    var turn = place.translatedBy(x: N, y: N).rotated(by: .pi)
    return (p.copy(using: &place)!, p.copy(using: &turn)!)
}

func outline(_ line: CGPath, _ f: Form, width: CGFloat? = nil) -> CGPath {
    line.copy(strokingWithWidth: (width ?? f.width) * f.scale, lineCap: f.cap, lineJoin: .round, miterLimit: 10)
}

// MARK: - Finishes

/// A solid bar with a flat top: body colour, light from above, lit and shaded edges, and a cast shadow.
func bar(_ c: CGContext, _ shape: CGPath, _ color: UInt32, lift: CGFloat = 12, sheen: CGFloat = 0.16) {
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -lift), blur: lift * 2, color: rgb(0x000000, 0.5))
    fill(c, shape, rgb(color))
    c.restoreGState()
    let box = shape.boundingBox
    inside(c, shape) {
        gradient(
            c, [rgb(0xFFFFFF, sheen), rgb(0xFFFFFF, 0), rgb(0x000000, sheen)], [0, 0.5, 1],
            from: CGPoint(x: 0, y: box.minY), to: CGPoint(x: 0, y: box.maxY))
    }
    edge(c, shape, dy: 3.5, rgb(0xFFFFFF, 0.55))
    edge(c, shape, dy: -3.5, rgb(0x000000, 0.28))
}

struct Variation {
    let id: String
    let name: String
    let draw: (CGContext) -> Void
}

enum Tone {
    static let inkTop: UInt32 = 0x26262B, inkBottom: UInt32 = 0x0D0D0F
    static let bone: UInt32 = 0xF2EEE6
    static let vermilion: UInt32 = 0xE8452C
}

/// The clasp in its plain finish: bone over vermilion on ink.
func plain(_ c: CGContext, _ f: Form) {
    tile(c, top: Tone.inkTop, bottom: Tone.inkBottom)
    let h = hooks(f)
    bar(c, outline(h.lower, f), Tone.vermilion)
    bar(c, outline(h.upper, f), Tone.bone)
}

// MARK: - More finishes

struct Enamel {
    let dark: UInt32, base: UInt32, light: UInt32
    static let bone = Enamel(dark: 0xA9A294, base: 0xEFEAE0, light: 0xFFFFFF)
    static let vermilion = Enamel(dark: 0x9C2513, base: 0xE8452C, light: 0xFF9079)
    static let ink = Enamel(dark: 0x030304, base: 0x1D1D21, light: 0x5A5A62)
    static let brass = Enamel(dark: 0x7E5A20, base: 0xC89B4E, light: 0xF8E6B4)
}

/// A bent rod with a round section: shaded like a cylinder, with a line of light along it.
func rod(_ c: CGContext, _ line: CGPath, _ f: Form, _ e: Enamel, lift: CGFloat = 14) {
    let w = f.width * f.scale
    let shape = outline(line, f)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -lift), blur: lift * 2, color: rgb(0x000000, 0.55))
    fill(c, shape, rgb(e.dark))
    c.restoreGState()
    inside(c, shape) {
        c.setLineCap(f.cap)
        c.setLineJoin(.round)
        let steps = 18
        for k in 0..<steps {
            let t = CGFloat(k) / CGFloat(steps - 1)
            let color = t < 0.45 ? mix(e.dark, e.base, t / 0.45) : mix(e.base, e.light, (t - 0.45) / 0.55 * 0.55)
            c.addPath(shifted(line, -w * 0.07 * t, -w * 0.13 * t))
            c.setStrokeColor(color)
            c.setLineWidth(w * (1 - 0.8 * t))
            c.strokePath()
        }
        c.addPath(shifted(line, -w * 0.1, -w * 0.25))
        c.setStrokeColor(rgb(0xFFFFFF, 0.5))
        c.setLineWidth(w * 0.07)
        c.strokePath()
    }
}

/// A channel cut into the surface.
func channel(_ c: CGContext, _ shape: CGPath, top: UInt32, bottom: UInt32, depth: CGFloat = 14) {
    let box = shape.boundingBox
    inside(c, shape) {
        gradient(c, [rgb(top), rgb(bottom)], [0, 1], from: CGPoint(x: 0, y: box.minY), to: CGPoint(x: 0, y: box.maxY))
        c.setShadow(offset: CGSize(width: 0, height: -depth), blur: depth * 1.6, color: rgb(0x000000, 0.7))
        let outside = CGMutablePath()
        outside.addRect(CGRect(x: -400, y: -400, width: N + 800, height: N + 800))
        outside.addPath(shape)
        fill(c, outside, rgb(0x000000), rule: .evenOdd)
    }
    // Light on the lower lip.
    c.saveGState()
    let lip = CGMutablePath()
    lip.addPath(shifted(shape, 0, 4))
    lip.addPath(shape)
    c.addPath(lip)
    c.clip(using: .evenOdd)
    fill(c, shifted(shape, 0, 4), rgb(0xFFFFFF, 0.2))
    c.restoreGState()
}

/// A pane of glass standing off the surface.
func glass(_ c: CGContext, _ shape: CGPath, tint: UInt32, strength: CGFloat = 0.3) {
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -16), blur: 30, color: rgb(0x000000, 0.35))
    fill(c, shape, rgb(tint, strength))
    c.restoreGState()
    let box = shape.boundingBox
    inside(c, shape) {
        gradient(
            c, [rgb(0xFFFFFF, 0.42), rgb(0xFFFFFF, 0.04), rgb(0xFFFFFF, 0.16)], [0, 0.55, 1],
            from: CGPoint(x: box.minX, y: box.minY), to: CGPoint(x: box.maxX, y: box.maxY))
    }
    edge(c, shape, dx: 2, dy: 4, rgb(0xFFFFFF, 0.85))
    edge(c, shape, dx: -2, dy: -4, rgb(0xFFFFFF, 0.3))
}

/// A hook folded from flat strip: three straight pieces meeting at mitred corners, each catching the light differently.
func folded(_ c: CGContext, upper: Bool, _ shades: [UInt32]) {
    let l: CGFloat = 296, r: CGFloat = 606, t: CGFloat = 238, b: CGFloat = 560, w: CGFloat = 104
    let pieces: [[(CGFloat, CGFloat)]] = [
        [(r, t), (l, t), (l + w, t + w), (r, t + w)],
        [(l, t), (l, b + w), (l + w, b), (l + w, t + w)],
        [(l, b + w), (r, b + w), (r, b), (l + w, b)],
    ]
    var turn = CGAffineTransform(translationX: N, y: N).rotated(by: .pi)
    var paths: [CGPath] = []
    let all = CGMutablePath()
    for piece in pieces {
        let p = CGMutablePath()
        p.addLines(between: piece.map { CGPoint(x: $0.0, y: $0.1) })
        p.closeSubpath()
        let placed: CGPath = upper ? p : p.copy(using: &turn)!
        paths.append(placed)
        all.addPath(placed)
    }
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: rgb(0x000000, 0.5))
    fill(c, all, rgb(shades[1]))
    c.restoreGState()
    for (index, p) in paths.enumerated() {
        // Turned half way round, the piece that faced the light now faces away.
        let shade = shades[upper ? index : 2 - index]
        fill(c, p, rgb(shade))
        c.addPath(p)
        c.setStrokeColor(rgb(shade))
        c.setLineWidth(1.5)
        c.strokePath()
    }
}

// MARK: - The twenty

let origin = Form()
let heavy = Form(left: 312, right: 604, top: 270, bottom: 566, radius: 104, width: 108)
let round = Form(left: 296, right: 604, top: 252, bottom: 572, radius: 160, width: 92, cap: .round)
/// The form carried into the depth and material studies: round ends, generous weight.
let settled = Form(left: 300, right: 604, top: 250, bottom: 574, radius: 138, width: 104, cap: .round)
/// Both inner arms on the centre line, so one hook lies across the other.
let lapped = Form(left: 298, right: 640, top: 246, bottom: 512, radius: 118, width: 104)

func inkTile(_ c: CGContext) { tile(c, top: Tone.inkTop, bottom: Tone.inkBottom) }
func vermilionTile(_ c: CGContext) { tile(c, top: 0xF4634A, bottom: 0xD43A22, edgeLight: 0.35, rim: 0.14, glow: 0.16) }
func ceramicTile(_ c: CGContext) { tile(c, top: 0xFAF8F3, bottom: 0xE7E2D6, edgeLight: 0.9, rim: 0.5, glow: 0.3) }

let final: [Variation] = [
    // Form
    Variation(id: "c01", name: "Origin") { c in plain(c, origin) },
    Variation(id: "c02", name: "Heavy") { c in plain(c, heavy) },
    Variation(id: "c03", name: "Round") { c in plain(c, round) },
    Variation(id: "c04", name: "Short lip") { c in
        plain(c, Form(left: 300, right: 590, top: 262, bottom: 572, radius: 104, width: 96, outerEnd: 640, innerEnd: 520))
    },
    Variation(id: "c05", name: "Tilt") { c in
        plain(c, Form(left: 304, right: 596, top: 266, bottom: 568, radius: 130, width: 98, cap: .round, rotation: -.pi / 9))
    },
    Variation(id: "c06", name: "Bleed") { c in
        plain(c, Form(left: 300, right: 590, top: 262, bottom: 572, radius: 100, width: 92, outerEnd: 700, scale: 1.42))
    },
    Variation(id: "c07", name: "Lapped") { c in plain(c, lapped) },
    // Construction
    Variation(id: "c08", name: "Rods") { c in
        inkTile(c)
        let h = hooks(settled)
        rod(c, h.lower, settled, .vermilion)
        rod(c, h.upper, settled, .bone)
    },
    Variation(id: "c09", name: "Relief") { c in
        tile(c, top: 0x3A3A41, bottom: 0x1B1B1F, edgeLight: 0.22, rim: 0.12)
        let h = hooks(settled)
        bar(c, outline(h.lower, settled), 0x2B2B31, lift: 12, sheen: 0.14)
        bar(c, outline(h.upper, settled), 0x34343B, lift: 12, sheen: 0.14)
    },
    Variation(id: "c10", name: "Carved") { c in
        tile(c, top: 0x3A3A41, bottom: 0x1B1B1F, edgeLight: 0.22, rim: 0.12)
        let h = hooks(settled)
        channel(c, outline(h.lower, settled), top: 0x0C0C0E, bottom: 0x18181B)
        channel(c, outline(h.upper, settled), top: 0x0C0C0E, bottom: 0x18181B)
    },
    Variation(id: "c11", name: "Inlaid") { c in
        inkTile(c)
        let h = hooks(settled)
        channel(c, outline(h.lower, settled), top: 0xD63C24, bottom: 0xEE553A, depth: 5)
        channel(c, outline(h.upper, settled), top: 0xE4DFD4, bottom: 0xF6F2EA, depth: 5)
    },
    Variation(id: "c12", name: "Cloisonné") { c in
        inkTile(c)
        let h = hooks(settled)
        for (line, top, bottom) in [(h.lower, 0xD63C24 as UInt32, 0xEE553A as UInt32), (h.upper, 0xE4DFD4, 0xF6F2EA)] {
            bar(c, outline(line, settled), Enamel.brass.base, lift: 10, sheen: 0.28)
            channel(c, outline(line, settled, width: settled.width - 30), top: top, bottom: bottom, depth: 4)
        }
    },
    Variation(id: "c13", name: "Glass") { c in
        tile(c, top: 0xF4634A, bottom: 0xC8321C, edgeLight: 0.35, rim: 0.14, glow: 0.2)
        let h = hooks(settled)
        glass(c, outline(h.lower, settled), tint: 0x3A0C05, strength: 0.34)
        glass(c, outline(h.upper, settled), tint: 0xFFFFFF, strength: 0.3)
    },
    Variation(id: "c14", name: "Folded") { c in
        inkTile(c)
        folded(c, upper: false, [0xF2634A, 0xE8452C, 0xC43620])
        folded(c, upper: true, [0xFFFFFF, 0xEFEAE0, 0xD2CCBF])
    },
    // Material
    Variation(id: "c15", name: "Rods on vermilion") { c in
        vermilionTile(c)
        let h = hooks(settled)
        rod(c, h.lower, settled, .ink)
        rod(c, h.upper, settled, .bone)
    },
    Variation(id: "c16", name: "Rods on ceramic") { c in
        ceramicTile(c)
        let h = hooks(settled)
        rod(c, h.lower, settled, .vermilion, lift: 10)
        rod(c, h.upper, settled, .ink, lift: 10)
    },
    Variation(id: "c17", name: "Brass and enamel") { c in
        inkTile(c)
        let h = hooks(settled)
        rod(c, h.lower, settled, .vermilion)
        rod(c, h.upper, settled, .brass)
    },
    Variation(id: "c18", name: "One material") { c in
        inkTile(c)
        let h = hooks(settled)
        rod(c, h.lower, settled, .bone)
        rod(c, h.upper, settled, .bone)
    },
    Variation(id: "c19", name: "Lapped rods") { c in
        inkTile(c)
        var f = lapped
        f.cap = .round
        let h = hooks(f)
        rod(c, h.lower, f, .vermilion)
        rod(c, h.upper, f, .bone)
    },
    Variation(id: "c20", name: "Lapped on ceramic") { c in
        ceramicTile(c)
        let h = hooks(lapped)
        bar(c, outline(h.lower, lapped), 0x1D1D21, lift: 9)
        bar(c, outline(h.upper, lapped), Tone.vermilion, lift: 9)
    },
]

// MARK: - Export

func render(_ v: Variation) -> CGImage {
    let c = makeContext(Int(N), Int(N))
    c.translateBy(x: 0, y: N)
    c.scaleBy(x: 1, y: -1)
    v.draw(c)
    return c.makeImage()!
}

func write(_ image: CGImage, pixels: Int, _ url: URL) {
    let c = makeContext(pixels, pixels)
    c.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    try! NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!.write(to: url)
}

func sheet(_ items: [(Variation, CGImage)], columns: Int, to url: URL) {
    let cell = 300, rows = Int(ceil(Double(items.count) / Double(columns)))
    let s = makeContext(columns * cell, rows * (cell + 70))
    s.setFillColor(rgb(0x8E8E93))
    s.fill(CGRect(x: 0, y: 0, width: s.width, height: s.height))
    for (index, (_, image)) in items.enumerated() {
        let x = (index % columns) * cell
        let top = s.height - (index / columns) * (cell + 70)
        s.draw(image, in: CGRect(x: x + 10, y: top - cell + 10, width: cell - 20, height: cell - 20))
        var sx = x + 70
        for size in [64, 32, 16] {
            s.draw(image, in: CGRect(x: sx, y: top - cell - 62 + (64 - size) / 2, width: size, height: size))
            sx += size + 22
        }
    }
    try! NSBitmapImageRep(cgImage: s.makeImage()!).representation(using: .png, properties: [:])!.write(to: url)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "out", isDirectory: true)
try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let set = "twenty"
let chosen = final
let rendered = chosen.map { ($0, render($0)) }
for (v, image) in rendered {
    for size in [512, 128, 64, 32] { write(image, pixels: size, out.appendingPathComponent("\(v.id)-\(size).png")) }
}
sheet(rendered, columns: 5, to: out.appendingPathComponent("clasp-\(set).png"))
print("Wrote \(rendered.count) to \(out.path)")

