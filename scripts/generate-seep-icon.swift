import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Renders SEEP's 1024x1024 app icon: an 8x8 flood board, mid-flood, in the
// primary theme colors. The Orchard and Dusk variants come from
// generate-app-icons.swift, the same hue shift EST uses.
//
// swift scripts/generate-seep-icon.swift SEEP/Resources/Assets.xcassets/AppIcon.appiconset/Icon-1024.png

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: generate-seep-icon.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}

let side = 1024
let grid = 8
let colors: [(CGFloat, CGFloat, CGFloat)] = [
    (0.87, 0.32, 0.28),  // red
    (0.24, 0.43, 0.92),  // blue
    (0.94, 0.66, 0.20),  // yellow
    (0.61, 0.34, 0.78),  // purple
]
// A fixed board with the top-left region already large, so the icon reads
// as "a flood in progress" at every size.
let cells: [Int] = [
    0, 0, 0, 1, 2, 1, 3, 2,
    0, 0, 0, 0, 2, 3, 1, 1,
    0, 0, 1, 0, 0, 2, 3, 2,
    0, 0, 0, 0, 3, 1, 2, 3,
    2, 0, 0, 3, 1, 2, 0, 1,
    1, 3, 0, 0, 2, 3, 1, 2,
    3, 2, 1, 0, 0, 1, 2, 3,
    1, 3, 2, 3, 1, 0, 3, 1,
]

let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

context.setFillColor(CGColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: side, height: side))

let margin: CGFloat = 96
let gap: CGFloat = 10
let cell = (CGFloat(side) - margin * 2 - gap * CGFloat(grid - 1)) / CGFloat(grid)
for row in 0..<grid {
    for column in 0..<grid {
        let color = colors[cells[row * grid + column]]
        let x = margin + CGFloat(column) * (cell + gap)
        // CoreGraphics origin is bottom-left; flip rows so row 0 is on top.
        let y = margin + CGFloat(grid - 1 - row) * (cell + gap)
        let rect = CGRect(x: x, y: y, width: cell, height: cell)
        let path = CGPath(roundedRect: rect, cornerWidth: cell * 0.18, cornerHeight: cell * 0.18, transform: nil)
        context.setFillColor(CGColor(red: color.0, green: color.1, blue: color.2, alpha: 1))
        context.addPath(path)
        context.fillPath()
    }
}

guard let image = context.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
print("wrote \(url.path)")
