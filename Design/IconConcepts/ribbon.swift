// Signa icon exploration, round four: the folded ribbon, refined.
// One strip of metal, folded four times into an S. Geometry first, then materials.
//
//   swiftc -O Design/IconConcepts/ribbon.swift -o /tmp/signa-ribbon && /tmp/signa-ribbon Design/IconConcepts/out
import AppKit
import SwiftUI

let N: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

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
        return (x + (y - x) * max(0, min(1, t))) / 255
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

func inside(_ c: CGContext, _ path: CGPath, _ body: () -> Void) {
    c.saveGState()
    c.addPath(path)
    c.clip()
    body()
    c.restoreGState()
}

func linear(_ c: CGContext, _ colors: [CGColor], _ stops: [CGFloat], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops)!
    c.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// A crescent of light or shade along the edges of a shape that face one way.
func edge(_ c: CGContext, _ path: CGPath, dx: CGFloat = 0, dy: CGFloat = 0, _ color: CGColor) {
    inside(c, path) {
        let p = CGMutablePath()
        p.addPath(path)
        p.addPath(shifted(path, dx, dy))
        fill(c, p, color, rule: .evenOdd)
    }
}

/// Fine streaks, as on brushed or anodised metal. Drawn once, reused everywhere.
let grain: CGImage = {
    let size = 1024
    let c = makeContext(size, size)
    var seed: UInt64 = 0x5167_4E41
    func next() -> CGFloat {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return CGFloat((seed >> 33) & 0xFFFF) / 65535
    }
    for row in 0..<size {
        let v = next()
        c.setFillColor(CGColor(colorSpace: space, components: [v, v, v, 1])!)
        c.fill(CGRect(x: 0, y: row, width: size, height: 1))
    }
    return c.makeImage()!
}()

/// Fine speckle, as in cut stone.
let speckle: CGImage = {
    let size = 512
    let c = makeContext(size, size)
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

/// Lays the grain over whatever is inside the current clip. `along` true runs it left to right.
func brush(_ c: CGContext, in rect: CGRect, along: Bool, strength: CGFloat) {
    c.saveGState()
    c.setBlendMode(.softLight)
    c.setAlpha(strength)
    if along {
        c.draw(grain, in: rect)
    } else {
        c.translateBy(x: rect.midX, y: rect.midY)
        c.rotate(by: .pi / 2)
        c.draw(grain, in: CGRect(x: -rect.height / 2, y: -rect.width / 2, width: rect.height, height: rect.width))
    }
    c.restoreGState()
}

// MARK: - Materials

struct Material {
    let name: String
    let dark: UInt32, base: UInt32, light: UInt32
    /// How strongly the brushing shows.
    var brushed: CGFloat = 0.34
    /// Stone is matte and speckled, not brushed.
    var stone = false

    /// A tone from -1 (turned away from the light) to 1 (facing it).
    func tone(_ t: CGFloat) -> CGColor { t >= 0 ? mix(base, light, t) : mix(base, dark, -t) }

    static let titanium = Material(name: "Titanium", dark: 0x54575D, base: 0x8D9096, light: 0xCFD2D7)
    static let aluminium = Material(name: "Anodised aluminium", dark: 0x7C828C, base: 0xB9BEC7, light: 0xF2F4F7)
    static let bronze = Material(name: "Bronze", dark: 0x4F4330, base: 0x8B7859, light: 0xCDBB96, brushed: 0.22)
    static let champagne = Material(name: "Champagne", dark: 0xA8946E, base: 0xD8C7A4, light: 0xF6EDD8)
    static let indigo = Material(name: "Indigo", dark: 0x1C2040, base: 0x363C6E, light: 0x737AAE)
    static let petrol = Material(name: "Petrol", dark: 0x0B3038, base: 0x1B5560, light: 0x5399A5)
    static let graphite = Material(name: "Graphite", dark: 0x1D2025, base: 0x3A3E45, light: 0x6C727C)
    static let slate = Material(name: "Slate", dark: 0x222A33, base: 0x46515E, light: 0x7E8B9B, stone: true)
    static let sandstone = Material(name: "Sandstone", dark: 0x9A8467, base: 0xCDB899, light: 0xEFE0C9, stone: true)
}

/// The tile, in a material of its own. Leaves the context clipped to it.
func tile(_ c: CGContext, _ m: Material, lightness: CGFloat = 0) {
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: rgb(0x000000, 0.32))
    fill(c, tilePath, m.tone(lightness - 0.5))
    c.restoreGState()
    c.addPath(tilePath)
    c.clip()
    linear(
        c, [m.tone(lightness + 0.2), m.tone(lightness - 0.26)], [0, 1], from: CGPoint(x: 0, y: 100),
        to: CGPoint(x: 0, y: 924))
    let pool = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.1), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(
        pool, startCenter: CGPoint(x: 340, y: 200), startRadius: 0, endCenter: CGPoint(x: 340, y: 200),
        endRadius: 700, options: [])
    let area = CGRect(x: 100, y: 100, width: 824, height: 824)
    if m.stone {
        c.saveGState()
        c.setBlendMode(.softLight)
        c.setAlpha(0.2)
        c.draw(speckle, in: area)
        c.restoreGState()
    } else {
        brush(c, in: area, along: true, strength: m.brushed * 0.3)
    }
    edge(c, tilePath, dy: 4, rgb(0xFFFFFF, 0.28))
    edge(c, tilePath, dy: -4, rgb(0x000000, 0.2))
    c.addPath(tilePath)
    c.setStrokeColor(rgb(0xFFFFFF, 0.12))
    c.setLineWidth(4)
    c.strokePath()
}

// MARK: - The object

/// One flat face of the folded strip.
struct Facet {
    let points: [CGPoint]
    /// How squarely the face meets the light, -1 to 1.
    let tone: CGFloat
    /// Whether the strip runs left to right here (true) or top to bottom.
    let horizontal: Bool

    var path: CGPath {
        let p = CGMutablePath()
        p.addLines(between: points)
        p.closeSubpath()
        return p
    }
}

struct Ribbon {
    var facets: [Facet]
    /// The fold lines, drawn as fine creases.
    var creases: [(CGPoint, CGPoint)]

    var outline: CGPath {
        var p: CGPath = CGMutablePath()
        for f in facets { p = p.union(f.path) }
        return p
    }
}

/// A strip of width `w` folded four times into an S. `bar` is the length of
/// the three horizontal runs and `gap` the opening between them, both in strip widths.
func foldedS(w: CGFloat, bar: CGFloat = 4, gap: CGFloat = 1, mitredEnds: Bool = false, tones: [CGFloat]) -> Ribbon {
    let width = bar * w, height = (3 + 2 * gap) * w
    let x0 = (N - width) / 2, y0 = (N - height) / 2
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x0 + x * w, y: y0 + y * w) }
    let g = gap
    let endTop = mitredEnds ? [p(bar, 0), p(bar - 1, 1)] : [p(bar, 0), p(bar, 1)]
    let endBottom = mitredEnds ? [p(0, 3 + 2 * g), p(1, 2 + 2 * g)] : [p(0, 3 + 2 * g), p(0, 2 + 2 * g)]
    let facets = [
        Facet(points: [endTop[0], p(0, 0), p(1, 1), endTop[1]], tone: tones[0], horizontal: true),
        Facet(points: [p(0, 0), p(0, 2 + g), p(1, 1 + g), p(1, 1)], tone: tones[1], horizontal: false),
        Facet(points: [p(1, 1 + g), p(bar, 1 + g), p(bar - 1, 2 + g), p(0, 2 + g)], tone: tones[2], horizontal: true),
        Facet(
            points: [p(bar, 1 + g), p(bar, 3 + 2 * g), p(bar - 1, 2 + 2 * g), p(bar - 1, 2 + g)], tone: tones[3],
            horizontal: false),
        Facet(points: [p(bar - 1, 2 + 2 * g), p(bar, 3 + 2 * g), endBottom[0], endBottom[1]], tone: tones[4], horizontal: true),
    ]
    let creases = [
        (p(0, 0), p(1, 1)), (p(0, 2 + g), p(1, 1 + g)), (p(bar, 1 + g), p(bar - 1, 2 + g)),
        (p(bar, 3 + 2 * g), p(bar - 1, 2 + 2 * g)),
    ]
    return Ribbon(facets: facets, creases: creases)
}

/// Where round three left off: two separate hooks, three faces each.
func twoHooks(tones: [CGFloat]) -> Ribbon {
    let l: CGFloat = 296, r: CGFloat = 606, t: CGFloat = 238, b: CGFloat = 560, w: CGFloat = 104
    let upper: [[(CGFloat, CGFloat)]] = [
        [(r, t), (l, t), (l + w, t + w), (r, t + w)],
        [(l, t), (l, b + w), (l + w, b), (l + w, t + w)],
        [(l, b + w), (r, b + w), (r, b), (l + w, b)],
    ]
    var facets: [Facet] = []
    for (i, piece) in upper.enumerated() {
        facets.append(
            Facet(points: piece.map { CGPoint(x: N - $0.0, y: N - $0.1) }, tone: tones[2 - i] - 0.25, horizontal: i != 1))
    }
    for (i, piece) in upper.enumerated() {
        facets.append(Facet(points: piece.map { CGPoint(x: $0.0, y: $0.1) }, tone: tones[i], horizontal: i != 1))
    }
    return Ribbon(facets: facets, creases: [])
}

/// Draws the strip as a solid piece of material: cast shadow, thickness, lit faces, creases.
func draw(_ c: CGContext, _ ribbon: Ribbon, _ m: Material, thickness: CGFloat = 12) {
    let whole = ribbon.outline
    // A broad soft shadow and a tight one where the piece meets the tile.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -26), blur: 44, color: rgb(0x000000, 0.34))
    fill(c, whole, rgb(0x000000))
    c.restoreGState()
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -6 - thickness), blur: 10, color: rgb(0x000000, 0.4))
    fill(c, whole, rgb(0x000000))
    c.restoreGState()
    // The edge of the strip, seen from slightly above.
    var k = thickness
    while k > 0 {
        fill(c, shifted(whole, 0, k), m.tone(-1.25 + 0.35 * (1 - k / thickness)))
        k -= 1
    }
    for f in ribbon.facets {
        let path = f.path
        let box = path.boundingBox
        inside(c, path) {
            // Each face is a little brighter toward the light.
            linear(
                c, [m.tone(f.tone + 0.16), m.tone(f.tone - 0.12)], [0, 1], from: CGPoint(x: box.minX, y: box.minY),
                to: CGPoint(x: box.maxX, y: box.maxY))
            // A soft band of reflected light, as satin metal gives.
            let along = f.horizontal
            linear(
                c, [rgb(0xFFFFFF, 0), rgb(0xFFFFFF, 0.13), rgb(0xFFFFFF, 0)], [0.05, 0.32, 0.7],
                from: CGPoint(x: box.minX, y: box.minY),
                to: along ? CGPoint(x: box.maxX, y: box.minY) : CGPoint(x: box.minX, y: box.maxY))
            // The brushing follows the strip around every fold.
            brush(c, in: box.insetBy(dx: -60, dy: -60), along: f.horizontal, strength: m.brushed)
        }
        c.addPath(path)
        c.setStrokeColor(m.tone(f.tone))
        c.setLineWidth(1)
        c.strokePath()
    }
    for (a, b) in ribbon.creases {
        let line = CGMutablePath()
        line.move(to: a)
        line.addLine(to: b)
        c.addPath(line)
        c.setStrokeColor(rgb(0xFFFFFF, 0.3))
        c.setLineWidth(1.6)
        c.strokePath()
    }
    edge(c, whole, dy: 2.5, rgb(0xFFFFFF, 0.42))
}

// MARK: - Studies

struct Study {
    let id: String
    let name: String
    let draw: (CGContext) -> Void
}

let lit: [CGFloat] = [0.75, -0.1, 0.45, -0.55, 0.15]

let geometry: [Study] = [
    Study(id: "r01", name: "Two hooks") { c in
        tile(c, .graphite, lightness: -0.2)
        draw(c, twoHooks(tones: [0.75, 0.2, -0.3]), .titanium)
    },
    Study(id: "r02", name: "One strip") { c in
        tile(c, .graphite, lightness: -0.2)
        draw(c, foldedS(w: 112, tones: lit), .titanium)
    },
    Study(id: "r03", name: "More air") { c in
        tile(c, .graphite, lightness: -0.2)
        draw(c, foldedS(w: 92, bar: 4.6, gap: 1.3, tones: lit), .titanium)
    },
    Study(id: "r04", name: "Mitred ends") { c in
        tile(c, .graphite, lightness: -0.2)
        draw(c, foldedS(w: 100, bar: 4.4, gap: 1.15, mitredEnds: true, tones: lit), .titanium)
    },
    Study(id: "r05", name: "Square, lighter") { c in
        tile(c, .graphite, lightness: -0.2)
        draw(c, foldedS(w: 100, bar: 4.4, gap: 1.15, tones: lit), .titanium)
    },
]

/// The settled form: lighter strip, every cut at the same angle as the folds.
func settled() -> Ribbon { foldedS(w: 100, bar: 4.4, gap: 1.15, mitredEnds: true, tones: lit) }

func study(_ id: String, _ strip: Material, on ground: Material, lightness: CGFloat) -> Study {
    Study(id: id, name: "\(strip.name) on \(ground.name.lowercased())") { c in
        tile(c, ground, lightness: lightness)
        draw(c, settled(), strip)
    }
}

let materials: [Study] = [
    study("m01", .titanium, on: .slate, lightness: -0.45),
    study("m02", .champagne, on: .slate, lightness: -0.45),
    study("m03", .bronze, on: .slate, lightness: -0.45),
    study("m04", .aluminium, on: .indigo, lightness: -0.25),
    study("m05", .champagne, on: .indigo, lightness: -0.25),
    study("m06", .aluminium, on: .petrol, lightness: -0.25),
    study("m07", .bronze, on: .petrol, lightness: -0.35),
    study("m08", .titanium, on: .graphite, lightness: -0.2),
    study("m09", .indigo, on: .sandstone, lightness: 0.25),
    study("m10", .petrol, on: .sandstone, lightness: 0.25),
    study("m11", .bronze, on: .sandstone, lightness: 0.25),
    study("m12", .graphite, on: .aluminium, lightness: 0.2),
]

// MARK: - Export

func render(_ s: Study) -> CGImage {
    let c = makeContext(Int(N), Int(N))
    c.translateBy(x: 0, y: N)
    c.scaleBy(x: 1, y: -1)
    s.draw(c)
    return c.makeImage()!
}

func write(_ image: CGImage, pixels: Int, _ url: URL) {
    let c = makeContext(pixels, pixels)
    c.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    try! NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!.write(to: url)
}

func sheet(_ items: [(Study, CGImage)], columns: Int, to url: URL) {
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
let which = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "geometry"
let chosen = which == "geometry" ? geometry : materials
let rendered = chosen.map { ($0, render($0)) }
for (s, image) in rendered {
    for size in [512, 128, 64, 32] { write(image, pixels: size, out.appendingPathComponent("\(s.id)-\(size).png")) }
}
sheet(rendered, columns: 5, to: out.appendingPathComponent("ribbon-\(which).png"))
print("Wrote \(rendered.count) to \(out.path)")
