// Signa icon exploration, round two: silhouettes about identity.
// Black and white only. No colour, gradient, lighting or material.
//
//   swiftc -O Design/IconConcepts/silhouettes.swift -o /tmp/signa-silhouettes && /tmp/signa-silhouettes Design/IconConcepts/out
import AppKit
import SwiftUI

let N: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let black = CGColor(colorSpace: space, components: [0, 0, 0, 1])!
let white = CGColor(colorSpace: space, components: [1, 1, 1, 1])!
let center = CGPoint(x: N / 2, y: N / 2)

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    return c
}

// MARK: - Drawing vocabulary: add ink, or cut it away

func ink(_ c: CGContext, _ path: CGPath) {
    c.setBlendMode(.normal)
    c.addPath(path)
    c.setFillColor(black)
    c.fillPath()
}

func cut(_ c: CGContext, _ path: CGPath) {
    c.setBlendMode(.clear)
    c.addPath(path)
    c.setFillColor(black)
    c.fillPath()
    c.setBlendMode(.normal)
}

func line(_ path: CGPath, _ width: CGFloat, cap: CGLineCap = .round, join: CGLineJoin = .round) -> CGPath {
    path.copy(strokingWithWidth: width, lineCap: cap, lineJoin: join, miterLimit: 10)
}

func disc(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2), transform: nil)
}

func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, r: CGFloat = 0) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

func polygon(_ points: [(CGFloat, CGFloat)]) -> CGPath {
    let p = CGMutablePath()
    p.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
    p.closeSubpath()
    return p
}

func scaled(_ path: CGPath, _ s: CGFloat, about p: CGPoint = center, dx: CGFloat = 0, dy: CGFloat = 0) -> CGPath {
    var t = CGAffineTransform(translationX: p.x + dx, y: p.y + dy).scaledBy(x: s, y: s).translatedBy(x: -p.x, y: -p.y)
    return path.copy(using: &t)!
}

/// Sweeps a broad pen, held at a fixed angle, along a spine. The thick and
/// thin parts come from the pen, as they do in handwriting.
func written(
    _ c: CGContext, _ spine: CGPath, scale: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0, nib: CGFloat = 136,
    cutting: Bool = false
) {
    let angle: CGFloat = -.pi * 0.125
    c.setBlendMode(cutting ? .clear : .normal)
    c.setStrokeColor(black)
    c.setLineCap(.round)
    c.setLineJoin(.round)
    c.setLineWidth(6 * scale)
    for step in 0...320 {
        let t = CGFloat(step) / 320 - 0.5
        var shift = CGAffineTransform(translationX: cos(angle) * nib * t, y: sin(angle) * nib * t)
        c.addPath(scaled(spine.copy(using: &shift)!, scale, dx: dx, dy: dy))
        c.strokePath()
    }
    c.setBlendMode(.normal)
}

let spineS: CGPath = {
    let spine = CGMutablePath()
    spine.move(to: CGPoint(x: 656, y: 398))
    spine.addCurve(to: CGPoint(x: 522, y: 300), control1: CGPoint(x: 648, y: 338), control2: CGPoint(x: 594, y: 300))
    spine.addCurve(to: CGPoint(x: 388, y: 404), control1: CGPoint(x: 446, y: 300), control2: CGPoint(x: 388, y: 342))
    spine.addCurve(to: CGPoint(x: 512, y: 512), control1: CGPoint(x: 388, y: 468), control2: CGPoint(x: 448, y: 490))
    spine.addCurve(to: CGPoint(x: 636, y: 620), control1: CGPoint(x: 576, y: 534), control2: CGPoint(x: 636, y: 556))
    spine.addCurve(to: CGPoint(x: 502, y: 724), control1: CGPoint(x: 636, y: 682), control2: CGPoint(x: 578, y: 724))
    spine.addCurve(to: CGPoint(x: 368, y: 626), control1: CGPoint(x: 430, y: 724), control2: CGPoint(x: 376, y: 686))
    return spine
}()

func writtenS(_ c: CGContext, scale: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0, cutting: Bool = false) {
    written(c, spineS, scale: scale, dx: dx, dy: dy, cutting: cutting)
}

/// A smooth closed curve from points given as (angle, radius) around the centre.
func blob(_ radius: (CGFloat) -> CGFloat) -> CGPath {
    let p = CGMutablePath()
    for i in 0..<720 {
        let a = CGFloat(i) / 720 * 2 * .pi
        let point = CGPoint(x: 512 + cos(a) * radius(a), y: 512 + sin(a) * radius(a))
        if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
    }
    p.closeSubpath()
    return p
}

/// Part of a circle as a path, angles in degrees, y pointing down.
func arc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, from: CGFloat, to: CGFloat) -> CGMutablePath {
    let p = CGMutablePath()
    let steps = 120
    for i in 0...steps {
        let a = (from + (to - from) * CGFloat(i) / CGFloat(steps)) * .pi / 180
        let point = CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r)
        if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
    }
    return p
}

/// A squared S drawn as one line.
func lineS(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat, startX: CGFloat? = nil, endX: CGFloat? = nil)
    -> CGPath
{
    let mid = (top + bottom) / 2
    let r = (mid - top) / 2
    let p = CGMutablePath()
    p.move(to: CGPoint(x: startX ?? right, y: top))
    p.addLine(to: CGPoint(x: left + r, y: top))
    p.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: left, y: top + r), radius: r)
    p.addArc(tangent1End: CGPoint(x: left, y: mid), tangent2End: CGPoint(x: left + r, y: mid), radius: r)
    p.addLine(to: CGPoint(x: right - r, y: mid))
    p.addArc(tangent1End: CGPoint(x: right, y: mid), tangent2End: CGPoint(x: right, y: mid + r), radius: r)
    p.addArc(tangent1End: CGPoint(x: right, y: bottom), tangent2End: CGPoint(x: right - r, y: bottom), radius: r)
    p.addLine(to: CGPoint(x: endX ?? left, y: bottom))
    return p
}

// MARK: - Silhouettes

struct Silhouette {
    let id: String
    let name: String
    let draw: (CGContext) -> Void
}

let silhouettes: [Silhouette] = [
    Silhouette(id: "s01-hand", name: "Hand") { c in
        writtenS(c, scale: 1.26)
    },
    Silhouette(id: "s02-signed", name: "Signed") { c in
        // The same S, finished the way a signature is: with a stroke beneath it.
        writtenS(c, scale: 1.04, dy: -62)
        let flourish = CGMutablePath()
        flourish.move(to: CGPoint(x: 226, y: 838))
        flourish.addCurve(
            to: CGPoint(x: 806, y: 792), control1: CGPoint(x: 400, y: 770), control2: CGPoint(x: 610, y: 850))
        written(c, flourish, scale: 1)
    },
    Silhouette(id: "s03-brand", name: "Brand") { c in
        // A ranch brand, the "Rocking S": bent iron, burnt in for good.
        let top = arc(512, 356, 118, from: -38, to: -270)
        let bottom = arc(512, 592, 118, from: -90, to: 142)
        let letter = CGMutablePath()
        letter.addPath(top)
        letter.addPath(bottom)
        ink(c, line(top, 80))
        ink(c, line(bottom, 80))
        ink(c, line(arc(512, 500, 352, from: 58, to: 122), 80))
    },
    Silhouette(id: "s04-whorl", name: "Whorl") { c in
        // A fingerprint whose innermost ridge is an S.
        let cy: CGFloat = 452
        let ridges: [(w: CGFloat, left: CGFloat, right: CGFloat)] = [(272, 760, 664), (192, 676, 800), (112, 812, 716)]
        for ridge in ridges {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 512 - ridge.w, y: ridge.left))
            p.addLine(to: CGPoint(x: 512 - ridge.w, y: cy))
            p.addArc(center: CGPoint(x: 512, y: cy), radius: ridge.w, startAngle: .pi, endAngle: 0, clockwise: false)
            p.addLine(to: CGPoint(x: 512 + ridge.w, y: ridge.right))
            ink(c, line(p, 44))
        }
        ink(c, line(lineS(left: 470, right: 554, top: 420, bottom: 636), 44))
    },
    Silhouette(id: "s05-hanko", name: "Hanko") { c in
        // A round name seal. The character grows out of the rim, as seal script does.
        ink(c, line(disc(512, 512, 266), 56))
        ink(c, line(lineS(left: 388, right: 636, top: 368, bottom: 656, startX: 722, endX: 302), 60, cap: .butt))
    },
    Silhouette(id: "s06-notary", name: "Notary") { c in
        // The embossed seal that makes a document official.
        ink(c, disc(512, 512, 276))
        for i in 0..<18 {
            let a = CGFloat(i) / 18 * 2 * .pi
            ink(c, disc(512 + cos(a) * 270, 512 + sin(a) * 270, 50))
        }
        cut(c, line(disc(512, 512, 212), 14))
        writtenS(c, scale: 0.66, cutting: true)
    },
    Silhouette(id: "s07-wax", name: "Wax") { c in
        // A wax seal. Pressed by hand, so no two share an outline.
        ink(
            c,
            blob { a in
                let slow: CGFloat = 26 * sin(3 * a + 0.6)
                let fast: CGFloat = 15 * sin(5 * a + 2.1)
                let lean: CGFloat = 9 * sin(2 * a + 4)
                return 276 + slow + fast + lean
            })
        cut(c, line(disc(512, 512, 196), 14))
        writtenS(c, scale: 0.62, cutting: true)
    },
    Silhouette(id: "s08-colours", name: "Colours") { c in
        // A banner hung from a crossbar: a standard, which is what "signa" means.
        ink(c, bar(497, 150, 30, 770, r: 15))
        ink(c, disc(512, 150, 34))
        ink(c, bar(292, 238, 440, 36, r: 18))
        ink(c, disc(292, 256, 28))
        ink(c, disc(732, 256, 28))
        ink(c, polygon([(332, 262), (692, 262), (692, 742), (512, 628), (332, 742)]))
    },
    Silhouette(id: "s09-script", name: "Script") { c in
        // A looped capital S in a running hand, the way a name begins on paper.
        let spine = CGMutablePath()
        spine.move(to: CGPoint(x: 236, y: 716))
        spine.addCurve(to: CGPoint(x: 640, y: 286), control1: CGPoint(x: 420, y: 668), control2: CGPoint(x: 640, y: 440))
        spine.addCurve(to: CGPoint(x: 548, y: 196), control1: CGPoint(x: 640, y: 226), control2: CGPoint(x: 596, y: 196))
        spine.addCurve(to: CGPoint(x: 470, y: 300), control1: CGPoint(x: 500, y: 196), control2: CGPoint(x: 470, y: 244))
        spine.addCurve(to: CGPoint(x: 712, y: 640), control1: CGPoint(x: 470, y: 430), control2: CGPoint(x: 712, y: 470))
        spine.addCurve(to: CGPoint(x: 520, y: 836), control1: CGPoint(x: 712, y: 760), control2: CGPoint(x: 628, y: 836))
        spine.addCurve(to: CGPoint(x: 356, y: 716), control1: CGPoint(x: 420, y: 836), control2: CGPoint(x: 356, y: 786))
        spine.addCurve(to: CGPoint(x: 440, y: 640), control1: CGPoint(x: 356, y: 668), control2: CGPoint(x: 396, y: 640))
        written(c, spine, scale: 1, nib: 84)
    },
    Silhouette(id: "s10-figure", name: "Figure") { c in
        // The S given a head: a person made from the initial.
        writtenS(c, scale: 1.0, dy: 86)
        ink(c, disc(560, 212, 84))
    },
]

// MARK: - Export

/// Draws a silhouette at 1024 px with a transparent ground, origin at the top left.
func mask(_ s: Silhouette) -> CGImage {
    let c = makeContext(Int(N), Int(N))
    c.translateBy(x: 0, y: N)
    c.scaleBy(x: 1, y: -1)
    c.beginTransparencyLayer(auxiliaryInfo: nil)
    s.draw(c)
    c.endTransparencyLayer()
    return c.makeImage()!
}

/// Fills `color` through a silhouette's alpha.
func paint(_ c: CGContext, _ mask: CGImage, _ color: CGColor, in rect: CGRect) {
    c.saveGState()
    c.clip(to: rect, mask: mask)
    c.setFillColor(color)
    c.fill(rect)
    c.restoreGState()
}

let tileShape = Path(
    roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerRadius: 185.4, style: .continuous
).cgPath

/// The mark alone, enlarged to fill the frame.
func alone(_ m: CGImage, pixels: Int) -> CGImage {
    let c = makeContext(pixels, pixels)
    let s = CGFloat(pixels)
    paint(c, m, black, in: CGRect(x: -s * 0.14, y: -s * 0.14, width: s * 1.28, height: s * 1.28))
    return c.makeImage()!
}

/// The mark on a flat tile, which is the outline macOS gives every icon.
func onTile(_ m: CGImage, dark: Bool, pixels: Int) -> CGImage {
    let c = makeContext(Int(N), Int(N))
    c.addPath(tileShape)
    c.setFillColor(dark ? black : white)
    c.fillPath()
    paint(c, m, dark ? white : black, in: CGRect(x: 102, y: 102, width: 820, height: 820))
    let big = c.makeImage()!
    let small = makeContext(pixels, pixels)
    small.draw(big, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return small.makeImage()!
}

func write(_ image: CGImage, _ url: URL) {
    try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "out", isDirectory: true)
try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let masks = silhouettes.map { ($0, mask($0)) }
for (s, m) in masks {
    write(alone(m, pixels: 640), out.appendingPathComponent("\(s.id)-alone.png"))
    for size in [256, 128, 64, 32] {
        write(onTile(m, dark: true, pixels: size), out.appendingPathComponent("\(s.id)-dark-\(size).png"))
        write(onTile(m, dark: false, pixels: size), out.appendingPathComponent("\(s.id)-light-\(size).png"))
    }
}

// Contact sheet: the mark alone, then on a dark and a light tile at 64, 32 and 16 pt.
let columns = 5, cellW = 300, cellH = 400, rows = Int(ceil(Double(masks.count) / Double(columns)))
let sheet = makeContext(columns * cellW, rows * cellH)
sheet.setFillColor(CGColor(colorSpace: space, components: [0.9, 0.9, 0.9, 1])!)
sheet.fill(CGRect(x: 0, y: 0, width: sheet.width, height: sheet.height))
for (index, (_, m)) in masks.enumerated() {
    let x = CGFloat((index % columns) * cellW)
    let top = CGFloat(sheet.height - (index / columns) * cellH)
    let panel = CGRect(x: x + 14, y: top - 286, width: 272, height: 272)
    sheet.setFillColor(white)
    sheet.fill(panel)
    sheet.draw(alone(m, pixels: 544), in: panel)
    var sx = x + 22
    for dark in [true, false] {
        for size in [64, 32, 16] as [CGFloat] {
            sheet.draw(
                onTile(m, dark: dark, pixels: Int(size) * 2),
                in: CGRect(x: sx, y: top - 374 + (64 - size) / 2, width: size, height: size))
            sx += size + 8
        }
        sx += 10
    }
}
write(sheet.makeImage()!, out.appendingPathComponent("silhouettes-sheet.png"))
print("Wrote \(masks.count) silhouettes to \(out.path)")
