import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1)
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

// Background: the school site's red family, light top-left to dark bottom-right.
let gradient = NSGradient(starting: color(0xCE4B51), ending: color(0x9E0C10))!
gradient.draw(in: NSRect(origin: .zero, size: size), angle: -60)

// Wordmark: serif, matching the app's launch-quote serif identity.
let font = NSFont(name: "Georgia-Bold", size: 480) ?? NSFont.systemFont(ofSize: 480, weight: .bold)
let text = NSAttributedString(string: "Eli", attributes: [
    .font: font,
    .foregroundColor: NSColor.white
])
let bounds = text.size()
// Optical centering: "Eli" has an ascender but no descender, so center the
// cap-to-baseline block rather than the full line box.
let baselineY = (1024 - font.capHeight) / 2
let originY = baselineY - (font.ascender - font.capHeight) - (bounds.height - font.ascender + font.descender) / 2 + 30
text.draw(at: NSPoint(x: (1024 - bounds.width) / 2, y: (1024 - bounds.height) / 2 - 40))

_ = originY


image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
rep.size = size
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("written \(rep.pixelsWide)x\(rep.pixelsHigh)")
