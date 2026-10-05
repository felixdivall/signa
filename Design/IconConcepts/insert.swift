// Signa icon, round six: one object, refined.
// A shell with a recessed square, half filled by a diagonal insert. Only proportion,
// depth, edges, light and material change between studies.
//
//   swiftc -O Design/IconConcepts/insert.swift -o /tmp/signa-insert && /tmp/signa-insert Design/IconConcepts/out
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

// MARK: - Machining

/// A rounded square centred on the tile, optionally shifted.
func plate(_ side: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0) -> CGPath {
    Path(
        roundedRect: CGRect(x: (N - side) / 2 + dx, y: (N - side) / 2 + dy, width: side, height: side),
        cornerRadius: side * 0.225, style: .continuous
    ).cgPath
}

let lowerLeft: CGPath = {
    let p = CGMutablePath()
    p.addLines(between: [CGPoint(x: -300, y: -300), CGPoint(x: N + 300, y: N + 300), CGPoint(x: -300, y: N + 300)])
    p.closeSubpath()
    return p
}()

let upperRight: CGPath = {
    let p = CGMutablePath()
    p.addLines(between: [CGPoint(x: -300, y: -300), CGPoint(x: N + 300, y: -300), CGPoint(x: N + 300, y: N + 300)])
    p.closeSubpath()
    return p
}()

enum Grain { case along, across, none }

/// Fills a face with a material: a tonal fall from the light, then its surface texture.
func face(
    _ c: CGContext, _ path: CGPath, _ m: Material, lightness: CGFloat, grain: Grain = .along, contrast: CGFloat = 0.2,
    texture: CGFloat = 1
) {
    let box = path.boundingBox
    inside(c, path) {
        linear(
            c, [m.tone(lightness + contrast), m.tone(lightness - contrast)], [0, 1],
            from: CGPoint(x: box.minX, y: box.minY), to: CGPoint(x: box.maxX, y: box.maxY))
        if m.stone {
            c.saveGState()
            c.setBlendMode(.softLight)
            c.setAlpha(0.2 * texture)
            c.draw(speckle, in: CGRect(x: 100, y: 100, width: 824, height: 824))
            c.restoreGState()
        } else if grain != .none {
            brush(
                c, in: CGRect(x: 100, y: 100, width: 824, height: 824), along: grain == .along,
                strength: m.brushed * texture)
        }
    }
}

/// The sloped band between two outlines. Raised, it catches light at the upper left; cut in, at the lower right.
func chamfer(_ c: CGContext, outer: CGPath, inner: CGPath, _ m: Material, lightness: CGFloat, raised: Bool) {
    let ring = CGMutablePath()
    ring.addPath(outer)
    ring.addPath(inner)
    let box = outer.boundingBox
    c.saveGState()
    c.addPath(ring)
    c.clip(using: .evenOdd)
    let lit = m.tone(lightness + 0.75), mid = m.tone(lightness), shade = m.tone(lightness - 0.8)
    linear(
        c, raised ? [lit, mid, shade] : [shade, mid, lit], [0.12, 0.5, 0.88],
        from: CGPoint(x: box.minX, y: box.minY), to: CGPoint(x: box.maxX, y: box.maxY))
    c.restoreGState()
}

func castShadow(_ c: CGContext, _ path: CGPath, height: CGFloat, alpha: CGFloat = 0.42) {
    c.saveGState()
    c.setShadow(offset: CGSize(width: height * 0.45, height: -height * 1.1), blur: height * 1.7, color: rgb(0x000000, alpha))
    fill(c, path, rgb(0x000000))
    c.restoreGState()
    c.saveGState()
    c.setShadow(offset: CGSize(width: 1, height: -3), blur: 5, color: rgb(0x000000, alpha * 0.8))
    fill(c, path, rgb(0x000000))
    c.restoreGState()
}

/// The shadow the upper and left walls of a recess throw onto its floor.
func wallShadow(_ c: CGContext, _ path: CGPath, depth: CGFloat, alpha: CGFloat = 0.6) {
    inside(c, path) {
        c.setShadow(offset: CGSize(width: depth * 0.45, height: -depth), blur: depth * 1.5, color: rgb(0x000000, alpha))
        let outside = CGMutablePath()
        outside.addRect(CGRect(x: -400, y: -400, width: N + 800, height: N + 800))
        outside.addPath(path)
        fill(c, outside, rgb(0x000000), rule: .evenOdd)
    }
}

/// A recess milled into the surface.
func pocket(
    _ c: CGContext, side: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0, depth: CGFloat, rim: CGFloat = 6,
    body: Material, bodyLightness: CGFloat, floor: Material? = nil, floorLightness: CGFloat, grain: Grain = .along
) {
    let mouth = plate(side + rim * 2, dx: dx, dy: dy), bottom = plate(side, dx: dx, dy: dy)
    chamfer(c, outer: mouth, inner: bottom, body, lightness: bodyLightness, raised: false)
    face(c, bottom, floor ?? body, lightness: floorLightness, grain: grain, contrast: 0.12, texture: floor == nil ? 0.45 : 0.8)
    wallShadow(c, bottom, depth: depth)
    // The lower lip catches the light.
    c.saveGState()
    let lip = CGMutablePath()
    lip.addPath(shifted(mouth, 0, 3))
    lip.addPath(mouth)
    c.addPath(lip)
    c.clip(using: .evenOdd)
    fill(c, shifted(mouth, 0, 3), rgb(0xFFFFFF, 0.22))
    c.restoreGState()
}

/// A raised plate standing on the surface.
func boss(
    _ c: CGContext, side: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0, height: CGFloat, rim: CGFloat = 7,
    _ m: Material, lightness: CGFloat, grain: Grain = .along, clip: CGPath? = nil
) {
    let foot = plate(side, dx: dx, dy: dy), top = plate(side - rim * 2, dx: dx, dy: dy)
    c.saveGState()
    if let clip {
        c.addPath(clip)
        c.clip()
    }
    castShadow(c, foot, height: height)
    chamfer(c, outer: foot, inner: top, m, lightness: lightness, raised: true)
    face(c, top, m, lightness: lightness, grain: grain)
    edge(c, top, dy: 2.5, rgb(0xFFFFFF, 0.3))
    c.restoreGState()
}

// MARK: - The object

enum Finish { case anodised, ceramic }

struct Spec {
    var shell: Material
    var shellLight: CGFloat = 0
    var recess: Material
    var recessLight: CGFloat = 0
    var insert: Material
    var insertLight: CGFloat = 0
    /// The colour of light where it catches an edge.
    var highlight: UInt32 = 0xFFFFFF
    var finish: Finish = .anodised

    /// Size of the recess and how round its corners are (0.225 matches the tile).
    var side: CGFloat = 500
    var ratio: CGFloat = 0.225
    var depth: CGFloat = 24
    /// Width of the sloped edge around the recess.
    var rim: CGFloat = 7
    /// How far the shadows spread, relative to the depth.
    var softness: CGFloat = 1.5
    /// The cut: shifted toward the upper right by this much, at this angle.
    var cutOffset: CGFloat = 0
    var cutAngle: CGFloat = 45
    /// Width of the bevel along the cut.
    var cutBevel: CGFloat = 0
    /// How far the insert sits below the surface of the shell.
    var drop: CGFloat = 0
    /// Direction of the brushing on the insert. Turning it is a change of finish, not of colour.
    var insertGrain: Grain = .along
    /// Strength of the shadows. Pale materials want less.
    var shadow: CGFloat = 0.62
    /// Faint flecks across the whole piece, as in a hand-mixed glaze.
    var fleck: CGFloat = 0
}

func square(_ side: CGFloat, ratio: CGFloat) -> CGPath {
    Path(
        roundedRect: CGRect(x: (N - side) / 2, y: (N - side) / 2, width: side, height: side),
        cornerRadius: side * ratio, style: .continuous
    ).cgPath
}

/// Everything on the lower-left side of the cut, widened by `grow` toward the upper right.
func belowCut(_ s: Spec, grow: CGFloat = 0) -> CGPath {
    let a = s.cutAngle * .pi / 180
    let along = CGPoint(x: cos(a), y: sin(a)), away = CGPoint(x: -sin(a), y: cos(a))
    let shift = (s.cutOffset + grow) / 2.squareRoot()
    let origin = CGPoint(x: N / 2 + shift, y: N / 2 - shift)
    let reach: CGFloat = 1400
    let p1 = CGPoint(x: origin.x - along.x * reach, y: origin.y - along.y * reach)
    let p2 = CGPoint(x: origin.x + along.x * reach, y: origin.y + along.y * reach)
    let p = CGMutablePath()
    p.addLines(between: [
        p1, p2, CGPoint(x: p2.x + away.x * reach, y: p2.y + away.y * reach),
        CGPoint(x: p1.x + away.x * reach, y: p1.y + away.y * reach),
    ])
    p.closeSubpath()
    return p
}

func drawObject(_ c: CGContext, _ s: Spec) {
    tile(c, s.shell, lightness: s.shellLight)
    let mouth = square(s.side + s.rim * 2, ratio: s.ratio), floor = square(s.side, ratio: s.ratio)

    // The sloped edge of the recess, with the highlight colour where it faces the light.
    chamfer(c, outer: mouth, inner: floor, s.shell, lightness: s.shellLight, raised: false)
    let ring = CGMutablePath()
    ring.addPath(mouth)
    ring.addPath(floor)
    c.saveGState()
    c.addPath(ring)
    c.clip(using: .evenOdd)
    let box = mouth.boundingBox
    linear(
        c, [rgb(s.highlight, 0), rgb(s.highlight, 0.5)], [0.55, 1], from: CGPoint(x: box.minX, y: box.minY),
        to: CGPoint(x: box.maxX, y: box.maxY))
    c.restoreGState()

    // The floor, in shadow under the upper wall.
    face(c, floor, s.recess, lightness: s.recessLight, contrast: 0.1, texture: 0.5)
    inside(c, floor) {
        c.setShadow(
            offset: CGSize(width: s.depth * 0.4, height: -s.depth), blur: s.depth * s.softness,
            color: rgb(0x000000, s.shadow))
        let outside = CGMutablePath()
        outside.addRect(CGRect(x: -400, y: -400, width: N + 800, height: N + 800))
        outside.addPath(floor)
        fill(c, outside, rgb(0x000000), rule: .evenOdd)
    }

    // The insert.
    let half = belowCut(s)
    c.saveGState()
    c.addPath(floor)
    c.clip()
    // It darkens the floor a little where the two meet.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 3, height: -4), blur: 16 * s.softness / 1.5, color: rgb(0x000000, s.shadow * 0.8))
    fill(c, half, rgb(0x000000))
    c.restoreGState()
    c.addPath(half)
    c.clip()
    face(
        c, floor, s.insert, lightness: s.insertLight, grain: s.finish == .ceramic ? .none : s.insertGrain,
        contrast: s.finish == .ceramic ? 0.26 : 0.16)
    if s.finish == .ceramic {
        // Glaze: one soft pool of reflected light.
        let glow = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.3), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
        let at = CGPoint(x: N / 2 - s.side * 0.26, y: N / 2 + s.side * 0.08)
        c.drawRadialGradient(glow, startCenter: at, startRadius: 0, endCenter: at, endRadius: s.side * 0.42, options: [])
    } else {
        // Anodised metal: a soft band across the brushing.
        linear(
            c, [rgb(0xFFFFFF, 0), rgb(0xFFFFFF, 0.14), rgb(0xFFFFFF, 0)], [0.1, 0.38, 0.75],
            from: CGPoint(x: (N - s.side) / 2, y: 0), to: CGPoint(x: (N + s.side) / 2, y: 0))
    }
    if s.drop > 0 {
        // Sitting below the surface, it takes a shadow from the wall beside it.
        c.setShadow(
            offset: CGSize(width: s.drop * 0.5, height: -s.drop), blur: s.drop * s.softness, color: rgb(0x000000, 0.5))
        let outside = CGMutablePath()
        outside.addRect(CGRect(x: -400, y: -400, width: N + 800, height: N + 800))
        outside.addPath(floor)
        fill(c, outside, rgb(0x000000), rule: .evenOdd)
        c.setShadow(offset: .zero, blur: 0, color: nil)
    }
    // The bevel along the cut catches the light.
    if s.cutBevel > 0 {
        let band = CGMutablePath()
        band.addPath(half)
        band.addPath(belowCut(s, grow: -s.cutBevel * 2.squareRoot()))
        c.saveGState()
        c.addPath(band)
        c.clip(using: .evenOdd)
        fill(c, floor, s.insert.tone(s.insertLight + 0.55))
        fill(c, floor, rgb(s.highlight, 0.45))
        c.restoreGState()
    }
    // A hairline where the insert meets the shell.
    c.addPath(floor)
    c.setStrokeColor(rgb(0x000000, s.shadow * 0.45))
    c.setLineWidth(3)
    c.strokePath()
    c.restoreGState()

    // Light on the lower lip of the recess.
    c.saveGState()
    let lip = CGMutablePath()
    lip.addPath(shifted(mouth, 0, 3))
    lip.addPath(mouth)
    c.addPath(lip)
    c.clip(using: .evenOdd)
    fill(c, shifted(mouth, 0, 3), rgb(s.highlight, 0.3))
    c.restoreGState()

    if s.fleck > 0 {
        c.saveGState()
        c.setBlendMode(.softLight)
        c.setAlpha(s.fleck)
        c.draw(speckle, in: CGRect(x: 100, y: 100, width: 824, height: 824))
        c.restoreGState()
    }
}

// MARK: - Materials

extension Material {
    // Empathiq
    static let warmGraphite = Material(name: "Warm graphite", dark: 0x1C1917, base: 0x3A3532, light: 0x6E6660, brushed: 0.13)
    static let charcoal = Material(name: "Charcoal", dark: 0x070606, base: 0x161413, light: 0x2C2826, brushed: 0.15)
    static let heartOrange = Material(name: "Orange", dark: 0xB24C1A, base: 0xF5793B, light: 0xFFAE82, brushed: 0.2)
    // Burnt copper
    static let darkSlate = Material(name: "Dark slate", dark: 0x161C23, base: 0x333D48, light: 0x64717E, stone: true)
    static let slateFloor = Material(name: "Slate floor", dark: 0x080B0F, base: 0x151A20, light: 0x2A323B, stone: true)
    static let burntCopper = Material(name: "Burnt copper", dark: 0x63301A, base: 0xA2552F, light: 0xD68D60, brushed: 0.42)
    // Clay
    static let stoneGrey = Material(name: "Stone grey", dark: 0x8A8379, base: 0xBAB3A8, light: 0xE4DED4, stone: true)
    static let terracotta = Material(name: "Terracotta", dark: 0x944730, base: 0xC46A4D, light: 0xE6A088, stone: true)
    // Electric indigo
    static let nightIndigo = Material(name: "Night indigo", dark: 0x07081A, base: 0x14163A, light: 0x30346F, brushed: 0.18)
    static let deepNavy = Material(name: "Deep navy", dark: 0x03050F, base: 0x0A0E2A, light: 0x1A2254, brushed: 0.12)
    static let violet = Material(name: "Violet", dark: 0x463C8A, base: 0x7466C4, light: 0xB4AAF0, brushed: 0.3)
    // Slate and gold
    static let champagneGold = Material(name: "Champagne gold", dark: 0x8A774C, base: 0xC2AB79, light: 0xECDCB3, brushed: 0.4)
    // Petrol
    static let coolGraphite = Material(name: "Graphite", dark: 0x15171B, base: 0x32353B, light: 0x63676F, brushed: 0.2)
    static let deepPetrol = Material(name: "Deep petrol", dark: 0x041A20, base: 0x0C3640, light: 0x1F6272, brushed: 0.15)
    static let clayShadow = Material(name: "Stone shadow", dark: 0x4B4640, base: 0x716B62, light: 0x979085, stone: true)
    static let oxidisedCopper = Material(name: "Oxidised copper", dark: 0x623A27, base: 0xA06748, light: 0xD29D7C, brushed: 0.36)
}

/// The primary direction: warm graphite, charcoal, orange, champagne light.
func empathiq() -> Spec {
    Spec(
        shell: .warmGraphite, shellLight: 0, recess: .charcoal, recessLight: 0.25, insert: .heartOrange, insertLight: 0,
        highlight: 0xF3E2C0)
}

// MARK: - Studies

struct Study {
    let id: String
    let name: String
    let draw: (CGContext) -> Void
}

func study(_ id: String, _ name: String, _ change: @escaping (inout Spec) -> Void) -> Study {
    Study(id: id, name: name) { c in
        var s = empathiq()
        change(&s)
        drawObject(c, s)
    }
}

let objects: [Study] = [
    study("g01", "Baseline") { _ in },
    study("g02", "Larger recess") { $0.side = 560 },
    study("g03", "Softer corners") { $0.ratio = 0.3 },
    study("g04", "Tighter corners") { $0.ratio = 0.16 },
    study("g05", "Deeper, softer shadow") { $0.depth = 40; $0.softness = 2.1; $0.rim = 10 },
    study("g06", "Bevelled cut") { $0.cutBevel = 12 },
    study("g07", "Insert set low") { $0.drop = 9; $0.rim = 14; $0.cutBevel = 8 },
    study("g08", "Cut moved off centre") { $0.cutOffset = 44; $0.cutBevel = 8 },
    study("g09", "Shallower cut") { $0.cutAngle = 37; $0.cutBevel = 8 },
]

/// The proportions carried into the material studies: a slightly deeper recess with a soft shadow,
/// a fine bevel on the cut, and the cut moved a little off centre.
func settle(_ s: inout Spec) {
    s.ratio = 0.24
    s.depth = 30
    s.softness = 1.8
    s.rim = 9
    s.cutBevel = 9
    s.cutOffset = 28
}

func material(_ id: String, _ name: String, _ spec: @escaping () -> Spec) -> Study {
    Study(id: id, name: name) { c in
        var s = spec()
        settle(&s)
        drawObject(c, s)
    }
}

let refined: [Study] = [
    material("d01", "Empathiq, anodised") { empathiq() },
    material("d02", "Empathiq, ceramic") {
        var s = empathiq()
        s.finish = .ceramic
        return s
    },
    material("d03", "Burnt copper") {
        Spec(
            shell: .darkSlate, shellLight: -0.05, recess: .slateFloor, recessLight: 0.1, insert: .burntCopper,
            highlight: 0xCDA57A)
    },
    material("d04", "Clay") {
        Spec(
            shell: .stoneGrey, shellLight: 0.05, recess: .clayShadow, recessLight: -0.1, insert: .terracotta,
            highlight: 0xF7EFDE)
    },
    material("d05", "Electric indigo") {
        Spec(
            shell: .nightIndigo, shellLight: 0.1, recess: .deepNavy, recessLight: 0.2, insert: .violet,
            highlight: 0xCDC6FA)
    },
    material("d06", "Slate and gold") {
        Spec(
            shell: .darkSlate, shellLight: -0.05, recess: .titanium, recessLight: -0.35, insert: .champagneGold,
            highlight: 0xF0E4C4)
    },
    material("d07", "Petrol") {
        Spec(
            shell: .coolGraphite, shellLight: 0, recess: .deepPetrol, recessLight: 0.25, insert: .oxidisedCopper,
            highlight: 0xE9C9A8)
    },
]

// MARK: - One material family

extension Material {
    /// A material part of the way from this one to another.
    func toward(_ other: Material, _ t: CGFloat) -> Material {
        func blend(_ a: UInt32, _ b: UInt32) -> UInt32 {
            var out: UInt32 = 0
            for shift in [16, 8, 0] as [UInt32] {
                let x = CGFloat((a >> shift) & 0xFF), y = CGFloat((b >> shift) & 0xFF)
                out |= UInt32((x + (y - x) * t).rounded()) << shift
            }
            return out
        }
        return Material(
            name: name, dark: blend(dark, other.dark), base: blend(base, other.base), light: blend(light, other.light),
            brushed: brushed, stone: stone)
    }

    // Warm ceramic
    static let ceramicShell = Material(name: "Warm grey", dark: 0xA69F97, base: 0xD3CDC5, light: 0xF4F0EA, brushed: 0)
    static let greige = Material(name: "Greige", dark: 0x80796F, base: 0xA8A197, light: 0xC8C1B7, brushed: 0)
    static let clay = Material(name: "Clay", dark: 0xA5826D, base: 0xC8A690, light: 0xE6CEBC, brushed: 0)
    // Champagne
    static let champagneShell = Material(name: "Champagne", dark: 0xA69370, base: 0xD5C4A2, light: 0xF4EAD3, brushed: 0.26)
    static let warmBronze = Material(name: "Warm bronze", dark: 0x5C4A33, base: 0x8A7354, light: 0xB39A78, brushed: 0.2)
    static let deepChampagne = Material(name: "Deep champagne", dark: 0x8F7C58, base: 0xBDA981, light: 0xE1D2B0, brushed: 0.2)
    // Stone
    static let taupe = Material(name: "Taupe", dark: 0x5E564B, base: 0x897E70, light: 0xACA193, stone: true)
    static let softTerracotta = Material(name: "Muted terracotta", dark: 0x9A6752, base: 0xBE8B74, light: 0xDDB29E, stone: true)
    // Warm graphite
    static let warmerGraphite = Material(name: "Warmer graphite", dark: 0x2B211B, base: 0x504137, light: 0x8A776B, brushed: 0.15)
    // Anodised aluminium
    static let lightTitanium = Material(name: "Light titanium", dark: 0x8A8E95, base: 0xBDC1C7, light: 0xEEF0F3, brushed: 0.28)
    static let mediumTitanium = Material(name: "Medium titanium", dark: 0x53565C, base: 0x7E8288, light: 0xA9ADB3, brushed: 0.2)
    static let bronzeTint = Material(name: "Bronze tint", dark: 0x7C7160, base: 0xADA08B, light: 0xD8CDB9, brushed: 0.2)
}

/// Each family twice: as described, and with the insert drawn part of the way back toward the shell.
func family(_ id: String, _ name: String, closer: CGFloat, _ spec: @escaping () -> Spec) -> [Study] {
    [
        Study(id: id + "a", name: name) { c in
            var s = spec()
            settle(&s)
            drawObject(c, s)
        },
        Study(id: id + "b", name: name + ", closer") { c in
            var s = spec()
            settle(&s)
            s.insert = s.insert.toward(s.shell, closer)
            drawObject(c, s)
        },
    ]
}

let unified: [Study] =
    family("u1", "Warm ceramic", closer: 0.5) {
        Spec(
            shell: .ceramicShell, shellLight: 0, recess: .greige, recessLight: -0.1, insert: .clay, highlight: 0xFFFBF4,
            finish: .ceramic, shadow: 0.36)
    }
    + family("u2", "Champagne", closer: 0.45) {
        Spec(
            shell: .champagneShell, shellLight: 0, recess: .warmBronze, recessLight: -0.15, insert: .deepChampagne,
            highlight: 0xFCF4DF, insertGrain: .across, shadow: 0.42)
    }
    + family("u3", "Stone", closer: 0.5) {
        Spec(
            shell: .sandstone, shellLight: 0.1, recess: .taupe, recessLight: -0.1, insert: .softTerracotta,
            highlight: 0xFCF3E3, shadow: 0.4)
    }
    + family("u4", "Warm graphite", closer: 0.45) {
        Spec(
            shell: .warmGraphite, shellLight: 0, recess: .charcoal, recessLight: 0.2, insert: .warmerGraphite,
            highlight: 0xE6D8C2, insertGrain: .across)
    }
    + family("u5", "Anodised aluminium", closer: 0.5) {
        Spec(
            shell: .lightTitanium, shellLight: 0, recess: .mediumTitanium, recessLight: -0.2, insert: .bronzeTint,
            highlight: 0xFFFFFF, insertGrain: .across, shadow: 0.42)
    }

// MARK: - One real colour

/// Shell and recess are neutrals leaning toward the insert's hue, so the colour belongs to the object.
func hue(
    _ id: String, _ name: String, shell: (UInt32, UInt32, UInt32), recess: (UInt32, UInt32, UInt32),
    insert: (UInt32, UInt32, UInt32), highlight: UInt32, light: Bool
) -> Study {
    material(id, name) {
        Spec(
            shell: Material(name: "Shell", dark: shell.0, base: shell.1, light: shell.2, brushed: light ? 0 : 0.13),
            recess: Material(name: "Recess", dark: recess.0, base: recess.1, light: recess.2, brushed: light ? 0 : 0.12),
            recessLight: light ? -0.15 : 0.2,
            insert: Material(name: "Insert", dark: insert.0, base: insert.1, light: insert.2, brushed: 0.2),
            highlight: highlight, finish: light ? .ceramic : .anodised, shadow: light ? 0.42 : 0.62)
    }
}

let colour: [Study] = [
    hue(
        "h1a", "Orange on warm ceramic", shell: (0xA99F92, 0xD9D0C5, 0xF5EFE7), recess: (0x3A2A20, 0x5E4636, 0x86695A),
        insert: (0xB24C1A, 0xF5793B, 0xFFAE82), highlight: 0xFFF3E0, light: true),
    hue(
        "h1b", "Orange on warm graphite", shell: (0x1C1917, 0x3A3532, 0x6E6660), recess: (0x120B07, 0x241711, 0x3F2B20),
        insert: (0xB24C1A, 0xF5793B, 0xFFAE82), highlight: 0xF3E2C0, light: false),
    hue(
        "h2a", "Petrol on cool ceramic", shell: (0x9AA5A6, 0xC9D2D2, 0xEEF3F3), recess: (0x0A2A31, 0x154650, 0x2C6C78),
        insert: (0x146676, 0x1F8FA3, 0x67C3D1), highlight: 0xF2FBFC, light: true),
    hue(
        "h2b", "Petrol on deep petrol", shell: (0x0E1C20, 0x1F3238, 0x44606A), recess: (0x030B0D, 0x0A1A1E, 0x163238),
        insert: (0x15707F, 0x2AA3B5, 0x7FD3DE), highlight: 0xCFEFF2, light: false),
    hue(
        "h3a", "Indigo on pale lavender", shell: (0xA09FB0, 0xCFCEDC, 0xF1F0F7), recess: (0x14163A, 0x262A60, 0x454A8E),
        insert: (0x3F38A8, 0x6C63E0, 0xA9A3F5), highlight: 0xF5F3FF, light: true),
    hue(
        "h3b", "Indigo on night indigo", shell: (0x07081A, 0x14163A, 0x30346F), recess: (0x03050F, 0x0A0E2A, 0x1A2254),
        insert: (0x463C9E, 0x7A6CF0, 0xBDB4FA), highlight: 0xCDC6FA, light: false),
    hue(
        "h4a", "Green on warm stone", shell: (0xA3A092, 0xD2CFC2, 0xF1EFE6), recess: (0x1C2619, 0x34432E, 0x566A4D),
        insert: (0x24623E, 0x3F8F5F, 0x86C7A0), highlight: 0xF6FAF0, light: true),
    hue(
        "h4b", "Green on forest graphite", shell: (0x121A15, 0x26322A, 0x4E6054), recess: (0x050906, 0x0E1711, 0x1E2E24),
        insert: (0x2C7048, 0x4FA873, 0x9AD8B2), highlight: 0xD5EEDD, light: false),
    hue(
        "h5a", "Ochre on champagne", shell: (0xAE9F80, 0xDDD0B4, 0xF6EED9), recess: (0x33240F, 0x574022, 0x82683F),
        insert: (0x9C6814, 0xD9972E, 0xF2C877), highlight: 0xFFF6DC, light: true),
    hue(
        "h5b", "Ochre on warm graphite", shell: (0x1C1917, 0x3A3532, 0x6E6660), recess: (0x120B07, 0x241711, 0x3F2B20),
        insert: (0x9C6814, 0xDFA033, 0xF4CC80), highlight: 0xF3E2C0, light: false),
    hue(
        "h6a", "Oxblood on blush stone", shell: (0xA99A94, 0xD8CBC6, 0xF5ECE8), recess: (0x2A0E12, 0x4A1B22, 0x74313B),
        insert: (0x7C1F2F, 0xB5364A, 0xDE7F8E), highlight: 0xFFF1F0, light: true),
    hue(
        "h6b", "Oxblood on plum graphite", shell: (0x1A1315, 0x342A2D, 0x625257), recess: (0x0A0506, 0x190D10, 0x321C21),
        insert: (0x8A2238, 0xC2405A, 0xE88A9B), highlight: 0xEFD3D6, light: false),
]

// MARK: - A colour identity

/// The whole object in one colour family, glazed: a coloured shell, a deeper recess, a lighter insert.
func glaze(
    _ id: String, _ name: String, shell: (UInt32, UInt32, UInt32), recess: (UInt32, UInt32, UInt32),
    insert: (UInt32, UInt32, UInt32), highlight: UInt32
) -> Study {
    material(id, name) {
        Spec(
            shell: Material(name: "Shell", dark: shell.0, base: shell.1, light: shell.2, brushed: 0),
            shellLight: 0.05,
            recess: Material(name: "Recess", dark: recess.0, base: recess.1, light: recess.2, brushed: 0),
            recessLight: 0,
            insert: Material(name: "Insert", dark: insert.0, base: insert.1, light: insert.2, brushed: 0),
            highlight: highlight, finish: .ceramic, shadow: 0.5)
    }
}

typealias Tones = (UInt32, UInt32, UInt32)

enum Family {
    static let burntOrange: (Tones, Tones, Tones, UInt32) = (
        (0x8C3415, 0xC8562B, 0xEE8A5C), (0x4A1806, 0x7A2C10, 0xA4472A), (0xD98A57, 0xF4B183, 0xFFD9BD), 0xFFE3CC
    )
    static let copperRed: (Tones, Tones, Tones, UInt32) = (
        (0x96301F, 0xD4573F, 0xF28C74), (0x501209, 0x842516, 0xAE3E2B), (0xD97F68, 0xF6A995, 0xFFD3C6), 0xFFE0D8
    )
    static let petrolBlue: (Tones, Tones, Tones, UInt32) = (
        (0x06434E, 0x0F6E7E, 0x3FA3B3), (0x021F27, 0x073945, 0x0F5562), (0x4BA6B1, 0x7FCFD8, 0xBDEBF0), 0xD9F5F8
    )
    static let deepTurquoise: (Tones, Tones, Tones, UInt32) = (
        (0x066661, 0x0E9C96, 0x4FCBC4), (0x02302E, 0x06524F, 0x0E7873), (0x66BDB5, 0x9FE3DC, 0xD2F5F1), 0xE0FAF7
    )
    static let forestGreen: (Tones, Tones, Tones, UInt32) = (
        (0x0F4129, 0x1F6B45, 0x4FA077), (0x051F12, 0x0E3A24, 0x1B5637), (0x66A983, 0x9AD2AF, 0xCFEEDB), 0xDFF5E6
    )
    static let aubergine: (Tones, Tones, Tones, UInt32) = (
        (0x3F1530, 0x6A2A52, 0xA0557F), (0x1F0719, 0x3A1230, 0x591F47), (0xAC6F95, 0xD69DBF, 0xF1CFE2), 0xF6DCEB
    )
    static let indigo: (Tones, Tones, Tones, UInt32) = (
        (0x28208A, 0x4338CA, 0x7F76EC), (0x100C48, 0x1F1A75, 0x30299A), (0x837CD8, 0xB4AEF6, 0xDDD9FD), 0xE4E1FF
    )
    static let deepRaspberry: (Tones, Tones, Tones, UInt32) = (
        (0x7C1A31, 0xB8324F, 0xE06C86), (0x3F0916, 0x6C1429, 0x91223C), (0xD0778B, 0xF3A3B4, 0xFDD2DB), 0xFFDDE4
    )
    static let burntSaffron: (Tones, Tones, Tones, UInt32) = (
        (0xA46A0C, 0xE39A22, 0xF9C566), (0x5A3202, 0x8F5306, 0xB77112), (0xE3B463, 0xFBD999, 0xFFEFC9), 0xFFF1CF
    )
    static let oceanBlue: (Tones, Tones, Tones, UInt32) = (
        (0x114794, 0x1F6FD0, 0x5B9FEE), (0x062350, 0x0D3F85, 0x1657AC), (0x6FA2DE, 0xA5CBF7, 0xD5E8FD), 0xDDEBFF
    )
}

func tonal(_ id: String, _ name: String, _ f: (Tones, Tones, Tones, UInt32)) -> Study {
    glaze(id, name, shell: f.0, recess: f.1, insert: f.2, highlight: f.3)
}

/// A family's shell and recess with a warm insert from another family.
func paired(_ id: String, _ name: String, _ f: (Tones, Tones, Tones, UInt32), insert: Tones) -> Study {
    glaze(id, name, shell: f.0, recess: f.1, insert: insert, highlight: f.3)
}

let saffronInsert: Tones = (0xC98A1C, 0xF2B441, 0xFDDC8E)
let coralInsert: Tones = (0xC96247, 0xF58A6B, 0xFFC0AD)
let apricotInsert: Tones = (0xD98A57, 0xF4B183, 0xFFD9BD)

let identity: [Study] = [
    tonal("k01", "Burnt orange", Family.burntOrange),
    tonal("k02", "Copper red", Family.copperRed),
    tonal("k03", "Petrol blue", Family.petrolBlue),
    tonal("k04", "Deep turquoise", Family.deepTurquoise),
    tonal("k05", "Forest green", Family.forestGreen),
    tonal("k06", "Aubergine", Family.aubergine),
    tonal("k07", "Indigo", Family.indigo),
    tonal("k08", "Deep raspberry", Family.deepRaspberry),
    tonal("k09", "Burnt saffron", Family.burntSaffron),
    tonal("k10", "Ocean blue", Family.oceanBlue),
    paired("k11", "Petrol blue with saffron", Family.petrolBlue, insert: saffronInsert),
    paired("k12", "Forest green with apricot", Family.forestGreen, insert: apricotInsert),
    paired("k13", "Aubergine with coral", Family.aubergine, insert: coralInsert),
    paired("k14", "Indigo with coral", Family.indigo, insert: coralInsert),
    paired("k15", "Ocean blue with saffron", Family.oceanBlue, insert: saffronInsert),
    paired("k16", "Deep turquoise with apricot", Family.deepTurquoise, insert: apricotInsert),
]

// MARK: - Glazes, refined

/// Hue in degrees, saturation and brightness from 0 to 1.
struct HSB {
    var h: CGFloat, s: CGFloat, b: CGFloat

    init(_ hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255, g = CGFloat((hex >> 8) & 0xFF) / 255, bl = CGFloat(hex & 0xFF) / 255
        let hi = max(r, g, bl), lo = min(r, g, bl), d = hi - lo
        var hue: CGFloat = 0
        if d > 0 {
            if hi == r { hue = (g - bl) / d } else if hi == g { hue = 2 + (bl - r) / d } else { hue = 4 + (r - g) / d }
            hue *= 60
            if hue < 0 { hue += 360 }
        }
        h = hue
        s = hi == 0 ? 0 : d / hi
        b = hi
    }

    init(h: CGFloat, s: CGFloat, b: CGFloat) {
        self.h = h
        self.s = s
        self.b = b
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

    func tones(light: CGFloat = 1.22, dark: CGFloat = 0.68) -> Tones {
        (
            HSB(h: h, s: s * 1.05, b: b * dark).hex, hex,
            HSB(h: h, s: s * 0.72, b: min(1, b * light)).hex
        )
    }
}

/// One glaze over the whole piece. The recess is the same colour pooled deeper;
/// the insert is the same colour thinned to a lighter value.
func ceramic(
    _ id: String, _ name: String, _ base: UInt32, pool: CGFloat = 0.55, thin: CGFloat = 0.72, wash: CGFloat = 0.45,
    insertHue: CGFloat = 0, poolHue: CGFloat = 0, poolSat: CGFloat = 1.08, insert override: Tones? = nil
) -> Study {
    material(id, name) {
        let shell = HSB(base)
        let recess = HSB(h: shell.h + poolHue, s: min(1, shell.s * poolSat), b: shell.b * pool)
        let lighter = HSB(h: shell.h + insertHue, s: shell.s * wash, b: shell.b + (1 - shell.b) * thin)
        let s1 = shell.tones(), s2 = recess.tones(light: 1.35, dark: 0.6), s3 = override ?? lighter.tones(light: 1.1, dark: 0.86)
        return Spec(
            shell: Material(name: "Shell", dark: s1.0, base: s1.1, light: s1.2, brushed: 0), shellLight: 0.05,
            recess: Material(name: "Recess", dark: s2.0, base: s2.1, light: s2.2, brushed: 0), recessLight: 0,
            insert: Material(name: "Insert", dark: s3.0, base: s3.1, light: s3.2, brushed: 0),
            highlight: HSB(h: shell.h + insertHue, s: shell.s * 0.16, b: 1).hex, finish: .ceramic, shadow: 0.5,
            fleck: 0.07)
    }
}

let glazes: [Study] = [
    // Burnt orange: richer, not brighter. Kept clear of red and of yellow.
    // A warm glaze pools toward rust, not brown, so the recess leans slightly red and stays saturated.
    ceramic("a1", "Burnt apricot", 0xD9773F, pool: 0.6, thin: 0.6, wash: 0.55, poolHue: -5, poolSat: 1.25),
    ceramic("a2", "Terracotta glaze", 0xCC5F34, pool: 0.58, thin: 0.6, wash: 0.55, poolHue: -5, poolSat: 1.22),
    ceramic("a3", "Fired clay", 0xBE5028, pool: 0.58, thin: 0.6, wash: 0.55, poolHue: -4, poolSat: 1.2),
    ceramic("a4", "Cinnamon", 0xB25A2C, pool: 0.58, thin: 0.6, wash: 0.55, poolHue: -4, poolSat: 1.2),
    ceramic("a5", "Autumn leaf", 0xCB6424, pool: 0.56, thin: 0.6, wash: 0.58, poolHue: -6, poolSat: 1.2),
    // Petrol: value, hue and the insert.
    ceramic("p1", "Petrol", 0x12697A),
    ceramic("p2", "Deep petrol, aqua insert", 0x0C5262, thin: 0.66, wash: 0.5, insertHue: -14),
    ceramic("p3", "Ocean teal", 0x1A8191),
    ceramic("p4", "Muted lagoon", 0x3A8790, wash: 0.4),
    ceramic("p5", "Blue-green ceramic, saffron insert", 0x14707C, insert: (0xC98A1C, 0xF2B441, 0xFDDC8E)),
    // Deep turquoise
    ceramic("t1", "Turquoise ceramic", 0x109C97),
    ceramic("t2", "Jade", 0x2E9E7E),
    ceramic("t3", "Mediterranean tile", 0x1493A8),
    ceramic("t4", "Oxidised copper glaze", 0x4AA190, wash: 0.4),
    ceramic("t5", "Blue-green pottery", 0x1A8888, pool: 0.5),
    // Sunset: between orange, pink and coral
    ceramic("s1", "Peach skin", 0xF09472, pool: 0.66, thin: 0.6, wash: 0.5, poolHue: -6, poolSat: 1.3),
    ceramic("s2", "Dusty apricot", 0xE48A62, pool: 0.64, thin: 0.6, wash: 0.52, poolHue: -6, poolSat: 1.28),
    ceramic("s3", "Warm coral", 0xEA775C, pool: 0.64, thin: 0.6, wash: 0.52, poolHue: -4, poolSat: 1.25),
    ceramic("s4", "Clay at golden hour", 0xDA7A52, pool: 0.62, thin: 0.6, wash: 0.54, poolHue: -6, poolSat: 1.25),
    ceramic("s5", "Dusk", 0xD46C55, pool: 0.62, thin: 0.6, wash: 0.52, poolHue: -4, poolSat: 1.22),
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
let which = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "objects"
let sets: [String: [Study]] = [
    "objects": objects, "unified": unified, "colour": colour, "identity": identity, "glazes": glazes,
]
let chosen = sets[which] ?? refined
let rendered = chosen.map { ($0, render($0)) }
for (s, image) in rendered {
    for size in [512, 128, 64, 32] { write(image, pixels: size, out.appendingPathComponent("\(s.id)-\(size).png")) }
}
sheet(rendered, columns: 5, to: out.appendingPathComponent("insert-\(which).png"))
print("Wrote \(rendered.count) to \(out.path)")
