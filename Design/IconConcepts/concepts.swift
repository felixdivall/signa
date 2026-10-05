// Signa icon exploration. Draws every concept at 1024 px and exports the
// sizes needed to judge them.
//
//   swiftc -O Design/IconConcepts/concepts.swift -o /tmp/signa-concepts && /tmp/signa-concepts Design/IconConcepts/out
import AppKit
import SwiftUI

let N: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

// MARK: - Palette

enum Ink {
    static let deep: UInt32 = 0x0E0E10
    static let base: UInt32 = 0x17171A
    static let lift: UInt32 = 0x232327
}
enum Paper {
    static let light: UInt32 = 0xF7F4ED
    static let base: UInt32 = 0xEDE8DD
    static let bone: UInt32 = 0xF4F1EA
}
enum Vermilion {
    static let light: UInt32 = 0xF2593D
    static let base: UInt32 = 0xE8452C
    static let deep: UInt32 = 0xD23A22
}

// MARK: - Toolkit

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha,
        ])!
}

/// A rounded square with continuous corners, the shape of a macOS icon.
func squircle(_ x: CGFloat, _ y: CGFloat, _ side: CGFloat, ratio: CGFloat = 0.225) -> CGPath {
    Path(roundedRect: CGRect(x: x, y: y, width: side, height: side), cornerRadius: side * ratio, style: .continuous)
        .cgPath
}

func centeredSquircle(_ side: CGFloat, ratio: CGFloat = 0.225) -> CGPath {
    squircle((N - side) / 2, (N - side) / 2, side, ratio: ratio)
}

let tilePath = squircle(100, 100, 824)

func makeContext(_ pixels: Int = Int(N)) -> CGContext {
    let c = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    return c
}

/// A 1024 context with the origin at the top left.
func makeCanvas() -> CGContext {
    let c = makeContext()
    c.translateBy(x: 0, y: N)
    c.scaleBy(x: 1, y: -1)
    return c
}

func verticalGradient(_ c: CGContext, _ top: CGColor, _ bottom: CGColor, from y0: CGFloat, to y1: CGFloat) {
    let g = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(
        g, start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// The base every concept sits on: a tile with a quiet tonal shift, a lit top
/// edge and a soft shadow. Leaves the context clipped to the tile.
func tile(_ c: CGContext, top: UInt32, bottom: UInt32, edge: CGFloat = 0.2) {
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: rgb(0x000000, 0.3))
    c.addPath(tilePath)
    c.setFillColor(rgb(bottom))
    c.fillPath()
    c.restoreGState()

    c.addPath(tilePath)
    c.clip()
    verticalGradient(c, rgb(top), rgb(bottom), from: 100, to: 924)

    var down = CGAffineTransform(translationX: 0, y: 4)
    c.addPath(tilePath)
    c.addPath(tilePath.copy(using: &down)!)
    c.setFillColor(rgb(0xFFFFFF, edge))
    c.fillPath(using: .evenOdd)
}

func fill(_ c: CGContext, _ path: CGPath, _ color: CGColor, rule: CGPathFillRule = .winding) {
    c.addPath(path)
    c.setFillColor(color)
    c.fillPath(using: rule)
}

func stroke(_ c: CGContext, _ path: CGPath, _ color: CGColor, width: CGFloat, cap: CGLineCap = .butt, join: CGLineJoin = .round) {
    c.addPath(path)
    c.setStrokeColor(color)
    c.setLineWidth(width)
    c.setLineCap(cap)
    c.setLineJoin(join)
    c.strokePath()
}

/// A soft shadow underneath a filled shape, for marks that sit on the tile.
func raised(_ c: CGContext, _ path: CGPath, _ color: CGColor, depth: CGFloat = 10, alpha: CGFloat = 0.28) {
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -depth), blur: depth * 2.2, color: rgb(0x000000, alpha))
    fill(c, path, color)
    c.restoreGState()
}

/// A shadow inside a shape, for marks pressed into the tile.
func pressed(_ c: CGContext, _ path: CGPath, depth: CGFloat = 10, alpha: CGFloat = 0.45) {
    c.saveGState()
    c.addPath(path)
    c.clip()
    c.setShadow(offset: CGSize(width: 0, height: -depth), blur: depth * 2, color: rgb(0x000000, alpha))
    let outside = CGMutablePath()
    outside.addRect(CGRect(x: -400, y: -400, width: N + 800, height: N + 800))
    outside.addPath(path)
    fill(c, outside, rgb(0x000000), rule: .evenOdd)
    c.restoreGState()
}

/// The letter S cut out of a rounded square with two slots.
func cutS(x: CGFloat, y: CGFloat, side: CGFloat) -> CGPath {
    let band = side / 5
    let body = CGMutablePath()
    body.addPath(squircle(x, y, side))
    // Upper slot opens to the right, lower slot opens to the left.
    let upper = CGMutablePath()
    upper.addRoundedRect(
        in: CGRect(x: x + band, y: y + band, width: side, height: band), cornerWidth: band / 2, cornerHeight: band / 2)
    let lower = CGMutablePath()
    lower.addRoundedRect(
        in: CGRect(x: x - band, y: y + band * 3, width: side, height: band), cornerWidth: band / 2,
        cornerHeight: band / 2)
    return body.subtracting(upper).subtracting(lower)
}

/// A squared-off S drawn as one line with generous corners.
func lineS(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat) -> CGPath {
    let mid = (top + bottom) / 2
    let r = (mid - top) / 2
    let p = CGMutablePath()
    p.move(to: CGPoint(x: right, y: top))
    p.addLine(to: CGPoint(x: left + r, y: top))
    p.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: left, y: top + r), radius: r)
    p.addArc(tangent1End: CGPoint(x: left, y: mid), tangent2End: CGPoint(x: left + r, y: mid), radius: r)
    p.addLine(to: CGPoint(x: right - r, y: mid))
    p.addArc(tangent1End: CGPoint(x: right, y: mid), tangent2End: CGPoint(x: right, y: mid + r), radius: r)
    p.addArc(tangent1End: CGPoint(x: right, y: bottom), tangent2End: CGPoint(x: right - r, y: bottom), radius: r)
    p.addLine(to: CGPoint(x: left, y: bottom))
    return p
}

/// A bracket open on the right; rotate it half a turn for its partner.
func hook(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat, radius r: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: right, y: top))
    p.addLine(to: CGPoint(x: left + r, y: top))
    p.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: left, y: top + r), radius: r)
    p.addLine(to: CGPoint(x: left, y: bottom - r))
    p.addArc(tangent1End: CGPoint(x: left, y: bottom), tangent2End: CGPoint(x: left + r, y: bottom), radius: r)
    p.addLine(to: CGPoint(x: right, y: bottom))
    return p
}

func halfTurn(_ path: CGPath) -> CGPath {
    var t = CGAffineTransform(translationX: N, y: N).rotated(by: .pi)
    return path.copy(using: &t)!
}

// MARK: - Concepts

struct Concept {
    let id: String
    let name: String
    let draw: (CGContext) -> Void
}

let concepts: [Concept] = [
    Concept(id: "01-monogram", name: "Monogram") { c in
        tile(c, top: Ink.lift, bottom: Ink.deep, edge: 0.16)
        raised(c, cutS(x: 292, y: 292, side: 440), rgb(Paper.bone), depth: 8)
    },
    Concept(id: "02-ligature", name: "Ligature") { c in
        tile(c, top: Vermilion.light, bottom: Vermilion.deep, edge: 0.3)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0x7A1A0C, 0.45))
        stroke(c, lineS(left: 350, right: 674, top: 300, bottom: 724), rgb(0xFFFFFF), width: 96)
        c.restoreGState()
    },
    Concept(id: "03-clasp", name: "Clasp") { c in
        tile(c, top: Ink.lift, bottom: Ink.deep, edge: 0.16)
        let upper = hook(left: 300, right: 590, top: 262, bottom: 572, radius: 96)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0x000000, 0.4))
        stroke(c, halfTurn(upper), rgb(Vermilion.base), width: 84)
        stroke(c, upper, rgb(Paper.bone), width: 84)
        c.restoreGState()
    },
    Concept(id: "04-signature", name: "Signature") { c in
        tile(c, top: Paper.light, bottom: Paper.base, edge: 0.9)
        // The spine of an S, swept by a broad pen held at a constant angle.
        let spine = CGMutablePath()
        spine.move(to: CGPoint(x: 656, y: 398))
        spine.addCurve(to: CGPoint(x: 522, y: 300), control1: CGPoint(x: 648, y: 338), control2: CGPoint(x: 594, y: 300))
        spine.addCurve(to: CGPoint(x: 388, y: 404), control1: CGPoint(x: 446, y: 300), control2: CGPoint(x: 388, y: 342))
        spine.addCurve(to: CGPoint(x: 512, y: 512), control1: CGPoint(x: 388, y: 468), control2: CGPoint(x: 448, y: 490))
        spine.addCurve(to: CGPoint(x: 636, y: 620), control1: CGPoint(x: 576, y: 534), control2: CGPoint(x: 636, y: 556))
        spine.addCurve(to: CGPoint(x: 502, y: 724), control1: CGPoint(x: 636, y: 682), control2: CGPoint(x: 578, y: 724))
        spine.addCurve(to: CGPoint(x: 368, y: 626), control1: CGPoint(x: 430, y: 724), control2: CGPoint(x: 376, y: 686))
        let nib: CGFloat = 136
        let angle: CGFloat = -.pi * 0.125
        for step in 0...272 {
            let t = CGFloat(step) / 272 - 0.5
            var shift = CGAffineTransform(translationX: cos(angle) * nib * t, y: sin(angle) * nib * t)
            stroke(c, spine.copy(using: &shift)!, rgb(Ink.base), width: 6, cap: .round)
        }
    },
    Concept(id: "05-impression", name: "Impression") { c in
        tile(c, top: Vermilion.light, bottom: Vermilion.deep, edge: 0.3)
        let well = centeredSquircle(420)
        c.saveGState()
        c.addPath(well)
        c.clip()
        verticalGradient(c, rgb(0xB42B16), rgb(0xCB3820), from: 302, to: 722)
        c.restoreGState()
        pressed(c, well, depth: 16, alpha: 0.55)
        // Light catching the lower lip of the recess.
        var down = CGAffineTransform(translationX: 0, y: 5)
        let lowered = well.copy(using: &down)!
        c.saveGState()
        let lip = CGMutablePath()
        lip.addPath(lowered)
        lip.addPath(well)
        c.addPath(lip)
        c.clip(using: .evenOdd)
        fill(c, lowered, rgb(0xFFFFFF, 0.3))
        c.restoreGState()
    },
    Concept(id: "06-chop", name: "Chop") { c in
        tile(c, top: Paper.light, bottom: Paper.base, edge: 0.9)
        let side: CGFloat = 252
        let x: CGFloat = 924 - 118 - side
        fill(c, squircle(x, x, side, ratio: 0.2), rgb(Vermilion.base))
        let inset = side * 0.2
        fill(c, cutS(x: x + inset, y: x + inset, side: side - inset * 2), rgb(Paper.light))
    },
    Concept(id: "07-constant", name: "Constant") { c in
        tile(c, top: Ink.lift, bottom: Ink.deep, edge: 0.16)
        let a = squircle(252, 252, 372)
        let b = squircle(400, 400, 372)
        c.saveGState()
        c.addPath(a)
        c.clip()
        fill(c, b, rgb(Vermilion.base))
        c.restoreGState()
        stroke(c, a, rgb(Paper.bone, 0.92), width: 22)
        stroke(c, b, rgb(Paper.bone, 0.92), width: 22)
    },
    Concept(id: "08-bond", name: "Bond") { c in
        tile(c, top: Vermilion.light, bottom: Vermilion.deep, edge: 0.3)
        let a = squircle(246, 246, 340)
        let b = squircle(438, 438, 340)
        let width: CGFloat = 66
        let gap: CGFloat = 26
        // Rings are woven on their own layer so one can pass under the other.
        c.beginTransparencyLayer(auxiliaryInfo: nil)
        stroke(c, b, rgb(0xFFFFFF), width: width)
        c.setBlendMode(.clear)
        stroke(c, a, rgb(0x000000), width: width + gap * 2)
        c.setBlendMode(.normal)
        stroke(c, a, rgb(0xFFFFFF), width: width)
        c.saveGState()
        c.clip(to: CGRect(x: 438 - 90, y: 586 - 90, width: 180, height: 180))
        c.setBlendMode(.clear)
        stroke(c, b, rgb(0x000000), width: width + gap * 2)
        c.setBlendMode(.normal)
        stroke(c, b, rgb(0xFFFFFF), width: width)
        c.restoreGState()
        c.endTransparencyLayer()
    },
    Concept(id: "09-core", name: "Core") { c in
        tile(c, top: 0x1D1113, bottom: 0x120A0B, edge: 0.14)
        let rings: [(CGFloat, UInt32, UInt32)] = [
            (632, 0x4A1810, 0x3A120C), (444, 0x9A2C19, 0x862414), (256, Vermilion.light, Vermilion.base),
        ]
        for (side, top, bottom) in rings {
            let path = centeredSquircle(side)
            c.saveGState()
            c.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: rgb(0x000000, 0.35))
            fill(c, path, rgb(bottom))
            c.restoreGState()
            c.saveGState()
            c.addPath(path)
            c.clip()
            verticalGradient(c, rgb(top), rgb(bottom), from: (N - side) / 2, to: (N + side) / 2)
            var down = CGAffineTransform(translationX: 0, y: 3)
            c.addPath(path)
            c.addPath(path.copy(using: &down)!)
            c.setFillColor(rgb(0xFFFFFF, 0.2))
            c.fillPath(using: .evenOdd)
            c.restoreGState()
        }
    },
    Concept(id: "10-print", name: "Print") { c in
        tile(c, top: Paper.light, bottom: Paper.base, edge: 0.9)
        // Ridges like a fingerprint, each one following the icon's own shape.
        let ridges: [(side: CGFloat, gapAt: CGFloat, gap: CGFloat)] = [
            (540, 0.13, 150), (416, 0.62, 130), (292, 0.36, 110), (168, 0.86, 84),
        ]
        for ridge in ridges {
            let path = centeredSquircle(ridge.side)
            let r = ridge.side * 0.225
            let length = 4 * (ridge.side - 2 * r) + 2 * .pi * r * 1.06
            c.saveGState()
            c.setLineDash(phase: -ridge.gapAt * length, lengths: [length - ridge.gap, ridge.gap])
            stroke(c, path, rgb(Ink.base), width: 38, cap: .round)
            c.restoreGState()
        }
        fill(c, centeredSquircle(52, ratio: 0.5), rgb(Vermilion.base))
    },
    Concept(id: "11-facet", name: "Facet") { c in
        tile(c, top: Vermilion.light, bottom: Vermilion.deep, edge: 0)
        func facet(_ points: [(CGFloat, CGFloat)], _ color: UInt32) {
            let p = CGMutablePath()
            p.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
            p.closeSubpath()
            fill(c, p, rgb(color))
            stroke(c, p, rgb(color), width: 1.5)
        }
        let o0: CGFloat = 100, o1: CGFloat = 372, o2: CGFloat = 652, o3: CGFloat = 924
        let i0: CGFloat = 322, i1: CGFloat = 412, i2: CGFloat = 612, i3: CGFloat = 702
        let m0: CGFloat = 367, m1: CGFloat = 657
        // Sides, lit from the upper left.
        facet([(o1, o0), (o2, o0), (i2, i0), (i1, i0)], 0xF7826A)
        facet([(o0, o1), (i0, i1), (i0, i2), (o0, o2)], 0xF16A50)
        facet([(o3, o1), (o3, o2), (i3, i2), (i3, i1)], 0xCB361F)
        facet([(o1, o3), (i1, i3), (i2, i3), (o2, o3)], 0xB82D18)
        // Corners, each split along its diagonal.
        facet([(o0, o0), (o1, o0), (i1, i0), (m0, m0)], 0xFA9580)
        facet([(o0, o0), (m0, m0), (i0, i1), (o0, o1)], 0xF57C63)
        facet([(o2, o0), (o3, o0), (m1, m0), (i2, i0)], 0xEE6448)
        facet([(o3, o0), (o3, o1), (i3, i1), (m1, m0)], 0xDC4A30)
        facet([(o0, o2), (i0, i2), (m0, m1), (o0, o3)], 0xDF4D33)
        facet([(o0, o3), (m0, m1), (i1, i3), (o1, o3)], 0xC83A22)
        facet([(o3, o2), (o3, o3), (m1, m1), (i3, i2)], 0xB02A16)
        facet([(o3, o3), (o2, o3), (i2, i3), (m1, m1)], 0xA42412)
        // The table.
        let table = CGMutablePath()
        table.addLines(between: [(i1, i0), (i2, i0), (i3, i1), (i3, i2), (i2, i3), (i1, i3), (i0, i2), (i0, i1)].map {
            CGPoint(x: $0.0, y: $0.1)
        })
        table.closeSubpath()
        c.saveGState()
        c.addPath(table)
        c.clip()
        let g = CGGradient(colorsSpace: space, colors: [rgb(0xF2593D), rgb(0xE23F26)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(g, start: CGPoint(x: i0, y: i0), end: CGPoint(x: i3, y: i3), options: [])
        c.restoreGState()
    },
    Concept(id: "12-proof", name: "Proof") { c in
        tile(c, top: Paper.light, bottom: Paper.base, edge: 0.9)
        let side: CGFloat = 356
        let a = (N - side) / 2, b = (N + side) / 2
        raised(c, squircle(a, a, side), rgb(Vermilion.base), depth: 6, alpha: 0.22)
        // Trim marks, as a printer would set them around finished work.
        let reach: CGFloat = 116, clear: CGFloat = 40
        for (x, y, dx, dy) in [(a, a, -1.0, -1.0), (b, a, 1.0, -1.0), (a, b, -1.0, 1.0), (b, b, 1.0, 1.0)] {
            let h = CGMutablePath()
            h.move(to: CGPoint(x: x + dx * clear, y: y))
            h.addLine(to: CGPoint(x: x + dx * reach, y: y))
            let v = CGMutablePath()
            v.move(to: CGPoint(x: x, y: y + dy * clear))
            v.addLine(to: CGPoint(x: x, y: y + dy * reach))
            stroke(c, h, rgb(Ink.base), width: 12)
            stroke(c, v, rgb(Ink.base), width: 12)
        }
    },
    Concept(id: "13-keyline", name: "Keyline") { c in
        tile(c, top: Ink.lift, bottom: Ink.deep, edge: 0.16)
        // The grid every macOS icon is drawn on, reduced to its essentials.
        let line = rgb(Vermilion.light)
        let w: CGFloat = 13
        stroke(c, centeredSquircle(540), line, width: w)
        stroke(c, CGPath(ellipseIn: CGRect(x: 312, y: 312, width: 400, height: 400), transform: nil), line, width: w)
        stroke(c, CGPath(ellipseIn: CGRect(x: 412, y: 412, width: 200, height: 200), transform: nil), line, width: w)
        for (x0, y0, x1, y1) in [(242.0, 512.0, 782.0, 512.0), (512.0, 242.0, 512.0, 782.0)] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: x0, y: y0))
            p.addLine(to: CGPoint(x: x1, y: y1))
            stroke(c, p, line, width: w)
        }
    },
    Concept(id: "14-twin", name: "Twin") { c in
        tile(c, top: Ink.lift, bottom: Ink.deep, edge: 0.16)
        // One shape, two finishes: as shipped, and as you chose.
        let shape = centeredSquircle(452)
        let gap: CGFloat = 15
        func half(_ lower: Bool) -> CGPath {
            let p = CGMutablePath()
            let s: CGFloat = lower ? 1 : -1
            p.addLines(between: [
                CGPoint(x: -200 + s * gap, y: -200 - s * gap), CGPoint(x: N + 200 + s * gap, y: N + 200 - s * gap),
                lower ? CGPoint(x: -200, y: N + 400) : CGPoint(x: N + 400, y: -200),
            ])
            p.closeSubpath()
            return p
        }
        c.saveGState()
        c.addPath(half(false))
        c.clip()
        let inner = centeredSquircle(452 - 44)
        stroke(c, inner, rgb(Paper.bone, 0.9), width: 22)
        c.restoreGState()
        c.saveGState()
        c.addPath(half(true))
        c.clip()
        fill(c, shape, rgb(Vermilion.base))
        c.restoreGState()
    },
    Concept(id: "15-seal", name: "Seal") { c in
        tile(c, top: Paper.light, bottom: Paper.base, edge: 0.9)
        let side: CGFloat = 500
        let x = (N - side) / 2
        fill(c, squircle(x, x, side), rgb(Vermilion.base))
        let inset = side * 0.21
        fill(c, cutS(x: x + inset, y: x + inset, side: side - inset * 2), rgb(Paper.light))
    },
    Concept(id: "16-inlay", name: "Inlay") { c in
        tile(c, top: Ink.lift, bottom: Ink.deep, edge: 0.16)
        // A fine line of brass set flush into the surface.
        let line = lineS(left: 356, right: 668, top: 296, bottom: 728)
        stroke(c, line, rgb(0x000000, 0.55), width: 58)
        c.saveGState()
        c.addPath(line)
        c.setLineWidth(46)
        c.setLineJoin(.round)
        c.replacePathWithStrokedPath()
        c.clip()
        let brass = CGGradient(
            colorsSpace: space, colors: [rgb(0xF1D9A4), rgb(0xD0A45C), rgb(0xA87A38)] as CFArray,
            locations: [0, 0.5, 1])!
        c.drawLinearGradient(brass, start: CGPoint(x: 356, y: 296), end: CGPoint(x: 668, y: 728), options: [])
        c.restoreGState()
    },
]

// MARK: - Export

func png(_ image: CGImage, pixels: Int) -> Data {
    let c = makeContext(pixels)
    c.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "out", isDirectory: true)
try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let only = CommandLine.arguments.count > 2 ? Set(CommandLine.arguments.dropFirst(2)) : nil

var masters: [(Concept, CGImage)] = []
for concept in concepts {
    let c = makeCanvas()
    concept.draw(c)
    let image = c.makeImage()!
    masters.append((concept, image))
    if let only, !only.contains(where: { concept.id.hasPrefix($0) }) { continue }
    for size in [512, 128, 64, 32] {
        try! png(image, pixels: size).write(to: out.appendingPathComponent("\(concept.id)-\(size).png"))
    }
}

// One sheet with everything, on a neutral ground, with the small sizes underneath.
let columns = 5, cell = 300, rows = Int(ceil(Double(masters.count) / Double(columns)))
let sheet = CGContext(
    data: nil, width: columns * cell, height: rows * (cell + 70), bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.interpolationQuality = .high
sheet.setFillColor(rgb(0x8E8E93))
sheet.fill(CGRect(x: 0, y: 0, width: sheet.width, height: sheet.height))
for (index, (_, image)) in masters.enumerated() {
    let x = (index % columns) * cell
    let top = sheet.height - (index / columns) * (cell + 70)
    sheet.draw(image, in: CGRect(x: x + 10, y: top - cell + 10, width: cell - 20, height: cell - 20))
    var sx = x + 70
    for size in [64, 32, 16] {
        sheet.draw(image, in: CGRect(x: sx, y: top - cell - 62 + (64 - size) / 2, width: size, height: size))
        sx += size + 22
    }
}
try! NSBitmapImageRep(cgImage: sheet.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: out.appendingPathComponent("sheet.png"))
print("Wrote \(masters.count) concepts to \(out.path)")
