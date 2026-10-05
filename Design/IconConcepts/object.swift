// Signa icon exploration, round five: the icon as a machined object.
// Pockets, steps and split finishes from the Impression, Core and Twin studies. No letters, no symbols.
//
//   swiftc -O Design/IconConcepts/object.swift -o /tmp/signa-object && /tmp/signa-object Design/IconConcepts/out
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

// MARK: - Studies

struct Study {
    let id: String
    let name: String
    let draw: (CGContext) -> Void
}

let objects: [Study] = [
    // Impression: one recess
    Study(id: "o01", name: "Shallow") { c in
        tile(c, .titanium, lightness: 0.05)
        pocket(c, side: 500, depth: 9, rim: 5, body: .titanium, bodyLightness: 0.05, floorLightness: -0.22)
    },
    Study(id: "o02", name: "Deep") { c in
        tile(c, .titanium, lightness: 0.05)
        pocket(c, side: 420, depth: 30, rim: 9, body: .titanium, bodyLightness: 0.05, floorLightness: -0.6)
    },
    Study(id: "o03", name: "Countersunk") { c in
        tile(c, .titanium, lightness: 0.05)
        pocket(c, side: 400, depth: 18, rim: 46, body: .titanium, bodyLightness: 0.05, floorLightness: -0.4)
    },
    Study(id: "o04", name: "Inlaid") { c in
        tile(c, .slate, lightness: -0.4)
        pocket(
            c, side: 470, depth: 5, rim: 4, body: .slate, bodyLightness: -0.4, floor: .champagne, floorLightness: 0.05)
    },
    Study(id: "o05", name: "Seated") { c in
        tile(c, .titanium, lightness: 0.05)
        pocket(c, side: 520, depth: 20, rim: 7, body: .titanium, bodyLightness: 0.05, floorLightness: -0.5)
        boss(c, side: 400, height: 12, .titanium, lightness: 0.2)
    },
    // Core: steps
    Study(id: "o06", name: "Stepped down") { c in
        tile(c, .graphite, lightness: 0.1)
        pocket(c, side: 620, depth: 12, body: .graphite, bodyLightness: 0.1, floorLightness: -0.15)
        pocket(c, side: 450, depth: 12, body: .graphite, bodyLightness: -0.15, floorLightness: -0.4)
        pocket(c, side: 280, depth: 12, body: .graphite, bodyLightness: -0.4, floorLightness: -0.7)
    },
    Study(id: "o07", name: "Stepped up") { c in
        tile(c, .aluminium, lightness: -0.35)
        boss(c, side: 620, height: 12, .aluminium, lightness: -0.15)
        boss(c, side: 450, height: 12, .aluminium, lightness: 0.05)
        boss(c, side: 280, height: 12, .aluminium, lightness: 0.3)
    },
    Study(id: "o08", name: "Lit core") { c in
        tile(c, .petrol, lightness: -0.45)
        pocket(c, side: 620, depth: 12, body: .petrol, bodyLightness: -0.45, floorLightness: -0.2)
        pocket(c, side: 450, depth: 12, body: .petrol, bodyLightness: -0.2, floorLightness: 0.15)
        pocket(c, side: 280, depth: 12, body: .petrol, bodyLightness: 0.15, floorLightness: 0.6)
    },
    Study(id: "o09", name: "Cascade") { c in
        tile(c, .slate, lightness: -0.4)
        boss(c, side: 560, dx: -28, dy: -28, height: 12, .titanium, lightness: -0.25)
        boss(c, side: 430, dx: 6, dy: 6, height: 12, .titanium, lightness: 0)
        boss(c, side: 300, dx: 40, dy: 40, height: 12, .titanium, lightness: 0.3)
    },
    Study(id: "o10", name: "Overlap") { c in
        tile(c, .slate, lightness: -0.4)
        boss(c, side: 420, dx: -72, dy: -72, height: 10, .titanium, lightness: -0.15, grain: .across)
        boss(c, side: 420, dx: 72, dy: 72, height: 22, .champagne, lightness: 0.05)
    },
    // Twin: one shape, two finishes
    Study(id: "o11", name: "Two finishes") { c in
        tile(c, .graphite, lightness: -0.1)
        boss(c, side: 520, height: 14, .aluminium, lightness: 0.1, grain: .across, clip: upperRight)
        boss(c, side: 520, height: 14, .aluminium, lightness: -0.2, grain: .along, clip: lowerLeft)
    },
    Study(id: "o12", name: "Split level") { c in
        tile(c, .graphite, lightness: -0.1)
        boss(c, side: 520, height: 8, .titanium, lightness: -0.25, grain: .across, clip: upperRight)
        c.saveGState()
        c.addPath(plate(520))
        c.clip()
        castShadow(c, lowerLeft, height: 14, alpha: 0.5)
        c.restoreGState()
        boss(c, side: 520, height: 20, .titanium, lightness: 0.15, grain: .along, clip: lowerLeft)
    },
    Study(id: "o13", name: "Half filled") { c in
        tile(c, .slate, lightness: -0.4)
        pocket(c, side: 500, depth: 24, rim: 7, body: .slate, bodyLightness: -0.4, floorLightness: -0.9)
        c.saveGState()
        c.addPath(lowerLeft)
        c.clip()
        face(c, plate(500), .champagne, lightness: 0.05)
        edge(c, plate(500), dy: -3, rgb(0x000000, 0.18))
        c.restoreGState()
    },
    Study(id: "o14", name: "Two metals") { c in
        tile(c, .graphite, lightness: -0.1)
        boss(c, side: 520, height: 14, .titanium, lightness: 0, grain: .across, clip: upperRight)
        boss(c, side: 520, height: 14, .champagne, lightness: 0, grain: .along, clip: lowerLeft)
    },
    // Embossing: a line only
    Study(id: "o15", name: "Raised line") { c in
        tile(c, .titanium, lightness: 0.05)
        let outer = plate(520), inner = plate(520 - 56)
        let ring = CGMutablePath()
        ring.addPath(outer)
        ring.addPath(inner)
        c.saveGState()
        c.addPath(ring)
        c.clip(using: .evenOdd)
        chamfer(c, outer: outer, inner: plate(520 - 20), .titanium, lightness: 0.05, raised: true)
        face(c, plate(520 - 20), .titanium, lightness: 0.28)
        chamfer(c, outer: plate(520 - 36), inner: inner, .titanium, lightness: 0.05, raised: false)
        c.restoreGState()
        // What the ridge shades on its lower right, inside and out.
        wallShadow(c, inner, depth: 7, alpha: 0.3)
    },
    Study(id: "o16", name: "Engraved line") { c in
        tile(c, .titanium, lightness: 0.05)
        let outer = plate(520), inner = plate(520 - 44)
        let groove = CGMutablePath()
        groove.addPath(outer)
        groove.addPath(inner)
        c.saveGState()
        c.addPath(groove)
        c.clip(using: .evenOdd)
        face(c, outer, .titanium, lightness: -0.55, grain: .none)
        c.setShadow(offset: CGSize(width: 4, height: -9), blur: 10, color: rgb(0x000000, 0.6))
        let outside = CGMutablePath()
        outside.addRect(CGRect(x: -400, y: -400, width: N + 800, height: N + 800))
        outside.addPath(outer)
        fill(c, outside, rgb(0x000000), rule: .evenOdd)
        fill(c, inner, rgb(0x000000))
        c.restoreGState()
        c.saveGState()
        let lip = CGMutablePath()
        lip.addPath(shifted(outer, 0, 3))
        lip.addPath(outer)
        c.addPath(lip)
        c.clip(using: .evenOdd)
        fill(c, shifted(outer, 0, 3), rgb(0xFFFFFF, 0.25))
        c.restoreGState()
        edge(c, inner, dy: 2.5, rgb(0xFFFFFF, 0.3))
    },
]

/// A well cut in steps, each floor a little brighter than the one above it.
func well(_ c: CGContext, _ m: Material, sides: [CGFloat], from: CGFloat, to: CGFloat, depth: CGFloat = 12, core: Material? = nil) {
    tile(c, m, lightness: from)
    for (index, side) in sides.enumerated() {
        let t = CGFloat(index + 1) / CGFloat(sides.count)
        let above = from + (to - from) * CGFloat(index) / CGFloat(sides.count)
        let isCore = index == sides.count - 1
        pocket(
            c, side: side, depth: depth, body: m, bodyLightness: above, floor: isCore ? core : nil,
            floorLightness: isCore && core != nil ? 0.05 : from + (to - from) * t)
    }
}

let refined: [Study] = [
    Study(id: "f01", name: "Well, petrol") { c in well(c, .petrol, sides: [620, 450, 280], from: -0.45, to: 0.6) },
    Study(id: "f02", name: "Well, indigo") { c in well(c, .indigo, sides: [620, 450, 280], from: -0.4, to: 0.65) },
    Study(id: "f03", name: "Well, two steps") { c in well(c, .petrol, sides: [600, 350], from: -0.45, to: 0.55, depth: 16) },
    Study(id: "f04", name: "Well, champagne floor") { c in
        well(c, .slate, sides: [620, 450, 280], from: -0.35, to: -0.75, core: .champagne)
    },
    Study(id: "f05", name: "Basin, sandstone") { c in well(c, .sandstone, sides: [620, 450, 280], from: 0.3, to: -0.55) },
    Study(id: "f06", name: "Terrace, aluminium") { c in
        tile(c, .aluminium, lightness: -0.35)
        boss(c, side: 620, height: 12, .aluminium, lightness: -0.15)
        boss(c, side: 450, height: 12, .aluminium, lightness: 0.05)
        boss(c, side: 280, height: 12, .aluminium, lightness: 0.3)
    },
    Study(id: "f07", name: "Seated, titanium") { c in
        tile(c, .titanium, lightness: 0.05)
        pocket(c, side: 520, depth: 20, rim: 7, body: .titanium, bodyLightness: 0.05, floorLightness: -0.55)
        boss(c, side: 404, height: 12, .titanium, lightness: 0.22)
    },
    Study(id: "f08", name: "Seated, champagne in slate") { c in
        tile(c, .slate, lightness: -0.4)
        pocket(c, side: 520, depth: 20, rim: 7, body: .slate, bodyLightness: -0.4, floorLightness: -0.95)
        boss(c, side: 404, height: 12, .champagne, lightness: 0.05)
    },
    Study(id: "f09", name: "Half filled, champagne in slate") { c in
        tile(c, .slate, lightness: -0.4)
        pocket(c, side: 500, depth: 24, rim: 7, body: .slate, bodyLightness: -0.4, floorLightness: -0.95)
        c.saveGState()
        c.addPath(lowerLeft)
        c.clip()
        face(c, plate(500), .champagne, lightness: 0.05)
        edge(c, plate(500), dy: -3, rgb(0x000000, 0.18))
        c.restoreGState()
    },
    Study(id: "f10", name: "Half filled, aluminium in petrol") { c in
        tile(c, .petrol, lightness: -0.35)
        pocket(c, side: 500, depth: 24, rim: 7, body: .petrol, bodyLightness: -0.35, floorLightness: -0.95)
        c.saveGState()
        c.addPath(lowerLeft)
        c.clip()
        face(c, plate(500), .aluminium, lightness: 0)
        edge(c, plate(500), dy: -3, rgb(0x000000, 0.18))
        c.restoreGState()
    },
    Study(id: "f11", name: "Two finishes, aluminium") { c in
        tile(c, .graphite, lightness: -0.1)
        boss(c, side: 520, height: 14, .aluminium, lightness: 0.1, grain: .across, clip: upperRight)
        boss(c, side: 520, height: 14, .aluminium, lightness: -0.2, grain: .along, clip: lowerLeft)
    },
    Study(id: "f12", name: "Split level, bronze") { c in
        tile(c, .graphite, lightness: -0.1)
        boss(c, side: 520, height: 8, .bronze, lightness: -0.3, grain: .across, clip: upperRight)
        c.saveGState()
        c.addPath(plate(520))
        c.clip()
        castShadow(c, lowerLeft, height: 14, alpha: 0.5)
        c.restoreGState()
        boss(c, side: 520, height: 20, .bronze, lightness: 0.15, grain: .along, clip: lowerLeft)
    },
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
let chosen = which == "objects" ? objects : refined
let rendered = chosen.map { ($0, render($0)) }
for (s, image) in rendered {
    for size in [512, 128, 64, 32] { write(image, pixels: size, out.appendingPathComponent("\(s.id)-\(size).png")) }
}
sheet(rendered, columns: 5, to: out.appendingPathComponent("object-\(which).png"))
print("Wrote \(rendered.count) to \(out.path)")
