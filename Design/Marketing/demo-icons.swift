// Four simple custom icons for screenshots and the website: the kind of thing
// a person might give their apps. Drawn in one family so they sit together.
//
//   swiftc -O Design/Marketing/demo-icons.swift -o /tmp/demo-icons && /tmp/demo-icons <output folder>
import AppKit
import SwiftUI

let N: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha,
        ])!
}

let tile = Path(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerRadius: 185.4, style: .continuous).cgPath

struct Icon {
    let name: String
    let top: UInt32, bottom: UInt32
    let mark: UInt32
    let draw: (CGContext) -> Void
}

func line(_ c: CGContext, _ points: [(CGFloat, CGFloat)], width: CGFloat) {
    c.setLineWidth(width)
    c.setLineCap(.round)
    c.setLineJoin(.round)
    c.move(to: CGPoint(x: points[0].0, y: points[0].1))
    for p in points.dropFirst() { c.addLine(to: CGPoint(x: p.0, y: p.1)) }
    c.strokePath()
}

let icons: [Icon] = [
    // A prompt, for a terminal.
    Icon(name: "terminal", top: 0x1A8191, bottom: 0x0C5262, mark: 0xE9F7F8) { c in
        line(c, [(330, 390), (470, 512), (330, 634)], width: 62)
        line(c, [(540, 644), (700, 644)], width: 62)
    },
    // Lines of text and a cursor, for an editor.
    Icon(name: "editor", top: 0x5248D6, bottom: 0x2C2596, mark: 0xECEAFF) { c in
        line(c, [(318, 392), (560, 392)], width: 56)
        line(c, [(318, 512), (470, 512)], width: 56)
        line(c, [(318, 632), (624, 632)], width: 56)
        line(c, [(600, 452), (600, 572)], width: 30)
    },
    // Bars of sound, for music.
    Icon(name: "music", top: 0x2A8A5C, bottom: 0x145C39, mark: 0xE7F6EC) { c in
        for (x, h) in [(332.0, 120.0), (422, 260), (512, 380), (602, 220), (692, 150)] as [(CGFloat, CGFloat)] {
            line(c, [(x, 512 - h / 2), (x, 512 + h / 2)], width: 56)
        }
    },
    // A tick, for a to-do list.
    Icon(name: "tasks", top: 0xE8A52E, bottom: 0xB3760E, mark: 0xFFF6DE) { c in
        line(c, [(338, 528), (462, 648), (690, 388)], width: 70)
    },
]

func render(_ icon: Icon) -> CGImage {
    let c = CGContext(
        data: nil, width: Int(N), height: Int(N), bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x: 0, y: N)
    c.scaleBy(x: 1, y: -1)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: rgb(0x000000, 0.32))
    c.addPath(tile)
    c.setFillColor(rgb(icon.bottom))
    c.fillPath()
    c.restoreGState()
    c.addPath(tile)
    c.clip()
    let g = CGGradient(colorsSpace: space, colors: [rgb(icon.top), rgb(icon.bottom)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [])
    let pool = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.14), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(pool, startCenter: CGPoint(x: 340, y: 200), startRadius: 0, endCenter: CGPoint(x: 340, y: 200), endRadius: 700, options: [])
    c.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: rgb(0x000000, 0.28))
    c.setStrokeColor(rgb(icon.mark))
    icon.draw(c)
    return c.makeImage()!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for icon in icons {
    let png = NSBitmapImageRep(cgImage: render(icon)).representation(using: .png, properties: [:])!
    try! png.write(to: out.appendingPathComponent("\(icon.name).png"))
}
print("Wrote \(icons.count) icons to \(out.path)")
