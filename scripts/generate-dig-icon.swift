import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Renders DIG's 1024x1024 app icon: a 5x5 minesweeper corner, part open with
// numbers, one flag, in the primary theme colors. The Orchard and Dusk
// variants come from generate-app-icons.swift.
//
// swift scripts/generate-dig-icon.swift DIG/Resources/Assets.xcassets/AppIcon.appiconset/Icon-1024.png

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: generate-dig-icon.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}

let side = 1024
let grid = 5
// 0 open zero, n>0 open number, -1 closed, -2 flag
let cells: [Int] = [
     0,  0,  0,  1, -1,
     0,  0,  1,  2, -1,
     0,  1,  2, -2, -1,
     1,  2, -1, -1, -1,
    -1, -2, -1, -1, -1,
]
let numberColors: [Int: (CGFloat, CGFloat, CGFloat)] = [
    1: (0.24, 0.43, 0.92),  // blue
    2: (0.20, 0.62, 0.40),  // green
    3: (0.87, 0.32, 0.28),  // red
]
let flag = (CGFloat(0.87), CGFloat(0.32), CGFloat(0.28))

let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

context.setFillColor(CGColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: side, height: side))

let margin: CGFloat = 96
let gap: CGFloat = 12
let cell = (CGFloat(side) - margin * 2 - gap * CGFloat(grid - 1)) / CGFloat(grid)
let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, cell * 0.62, nil)

for row in 0..<grid {
    for column in 0..<grid {
        let value = cells[row * grid + column]
        let x = margin + CGFloat(column) * (cell + gap)
        let y = margin + CGFloat(grid - 1 - row) * (cell + gap)
        let rect = CGRect(x: x, y: y, width: cell, height: cell)
        let path = CGPath(roundedRect: rect, cornerWidth: cell * 0.12, cornerHeight: cell * 0.12, transform: nil)
        if value >= 0 {
            context.setFillColor(CGColor(red: 0.20, green: 0.20, blue: 0.23, alpha: 1))
        } else {
            context.setFillColor(CGColor(red: 0.93, green: 0.92, blue: 0.90, alpha: 1))
        }
        context.addPath(path)
        context.fillPath()

        if value > 0, let color = numberColors[value] {
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: color.0, green: color.1, blue: color.2, alpha: 1),
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "\(value)", attributes: attributes))
            let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            context.textPosition = CGPoint(x: rect.midX - bounds.width / 2 - bounds.minX, y: rect.midY - bounds.height / 2 - bounds.minY)
            CTLineDraw(line, context)
        } else if value == -2 {
            // A flag: pole and a triangle.
            let poleX = rect.minX + cell * 0.38
            context.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.23, alpha: 1))
            context.fill(CGRect(x: poleX, y: rect.minY + cell * 0.2, width: cell * 0.06, height: cell * 0.6))
            context.setFillColor(CGColor(red: flag.0, green: flag.1, blue: flag.2, alpha: 1))
            context.move(to: CGPoint(x: poleX + cell * 0.06, y: rect.minY + cell * 0.8))
            context.addLine(to: CGPoint(x: poleX + cell * 0.06 + cell * 0.36, y: rect.minY + cell * 0.63))
            context.addLine(to: CGPoint(x: poleX + cell * 0.06, y: rect.minY + cell * 0.46))
            context.closePath()
            context.fillPath()
        }
    }
}

guard let image = context.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
print("wrote \(url.path)")
