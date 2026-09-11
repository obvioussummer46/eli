// Draws the Elisabethenschule icon: the serif „Eli" wordmark in the school
// reds, with the i-dot replaced by a white disc carrying a red check —
// direction 1g from the logo work (`Ranzen Logos.dc.html`).
//
//   swift Tools/make-eli-icon.swift SchulportalMobile/Assets.xcassets/AppIconEli.appiconset/AppIconEli.png
//
// The disc is placed off the font's own metrics (cap height, and the advance
// of the last glyph) rather than off hard-coded pixels, so it stays on the
// stem if the font or the size changes. The ratios come from measuring the
// shipped icon: radius 0.187× cap height, centre 1.069× cap height above the
// baseline. Output is opaque RGB — App Store Connect rejects an app icon
// that carries an alpha channel, so there is nothing left to flatten.
import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1)
}

let size = 1024.0
let deepRed: UInt32 = 0x9E0C10

// Georgia at this size gives the cap height the design was drawn at (361/1024).
let fontSize = 523.6
let font = NSFont(name: "Georgia-Bold", size: fontSize)
    ?? NSFont.systemFont(ofSize: fontSize, weight: .bold)

/// The design sets „Elı" with a dotless i, because the disc *is* the dot.
/// Georgia carries U+0131, but if a substituted font does not, fall back to a
/// normal „i" — the disc is far larger than the tittle and covers it anyway.
func wordmark() -> String {
    var character: UniChar = 0x0131
    var glyph: CGGlyph = 0
    let covered = CTFontGetGlyphsForCharacters(font as CTFont, &character, &glyph, 1)
    return covered ? "El\u{0131}" : "Eli"
}

// Core Text honours AppKit's colour attribute inconsistently; taking the
// colour from the context is the documented way and needs no guessing.
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
]

/// Typographic advance, not the inked bounds — the disc belongs over the
/// stem's advance box, the way the design places it.
func advance(_ string: String) -> Double {
    CTLineGetTypographicBounds(
        CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes)),
        nil, nil, nil)
}

let line = CTLineCreateWithAttributedString(NSAttributedString(string: wordmark(), attributes: attributes))
let textWidth = advance(wordmark())
let stemWidth = advance(String(wordmark().last!))

// Vertical: the measured baseline of the shipped icon, 710 of 1024.
let baseline = size - 710.0
let originX = (size - textWidth) / 2

let context = CGContext(data: nil, width: Int(size), height: Int(size),
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

// Background: the school site's red family, light top-left to dark bottom-right.
NSGradient(starting: color(0xCE4B51), ending: color(deepRed))!
    .draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -60)

// CTLineDraw puts the baseline exactly on the text position, which is the
// whole point of doing this by hand: the disc's placement depends on it.
context.setFillColor(NSColor.white.cgColor)
context.textPosition = CGPoint(x: originX, y: baseline)
CTLineDraw(line, context)

// The dot: centred on the last glyph's advance, sitting just clear of the caps.
let cap = font.capHeight
let centre = NSPoint(x: originX + textWidth - stemWidth / 2, y: baseline + cap * 1.069)
let radius = cap * 0.187
NSColor.white.setFill()
NSBezierPath(ovalIn: NSRect(x: centre.x - radius, y: centre.y - radius,
                            width: radius * 2, height: radius * 2)).fill()

// The check, as fractions of the radius (the design's 100-unit box, y flipped).
let check = NSBezierPath()
check.move(to: NSPoint(x: centre.x - 0.4348 * radius, y: centre.y - 0.0435 * radius))
check.line(to: NSPoint(x: centre.x - 0.1522 * radius, y: centre.y - 0.3261 * radius))
check.line(to: NSPoint(x: centre.x + 0.4348 * radius, y: centre.y + 0.3261 * radius))
check.lineWidth = 0.2609 * radius
check.lineCapStyle = .round
check.lineJoinStyle = .round
color(deepRed).setStroke()
check.stroke()

NSGraphicsContext.restoreGraphicsState()

let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("written \(rep.pixelsWide)x\(rep.pixelsHigh)")
