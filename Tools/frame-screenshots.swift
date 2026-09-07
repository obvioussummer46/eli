#!/usr/bin/env swift
// Turns a raw simulator screenshot into an App Store screenshot: gradient
// background, headline and subline on top, the screen below with rounded
// corners and a shadow, bleeding off the bottom edge. The output keeps the
// input's pixel size, so a 1320×2868 capture stays a valid 6.9" upload and
// a 2064×2752 capture a valid 13" iPad one. No alpha channel — App Store
// Connect rejects screenshots that carry one.
//
//   swift Tools/frame-screenshots.swift <in.png> <out.png> "Headline" "Subline"
import AppKit

let args = CommandLine.arguments
guard args.count == 5, let image = NSImage(contentsOfFile: args[1]),
      let shot = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("usage: frame-screenshots.swift <in.png> <out.png> \"Headline\" \"Subline\"\n", stderr)
    exit(1)
}
let headline = args[3], subline = args[4]
let width = shot.width, height = shot.height
let W = CGFloat(width), H = CGFloat(height)
let isPad = width > 1800
// Everything is designed at 1320 px wide and scaled from there.
let s = W / 1320

let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

// Background: the app's accent blue, darkening towards the bottom.
let colors = [NSColor(red: 0.00, green: 0.50, blue: 1.00, alpha: 1).cgColor,
              NSColor(red: 0.02, green: 0.26, blue: 0.68, alpha: 1).cgColor]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: H), end: CGPoint(x: W * 0.4, y: 0),
                        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Text.
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
paragraph.lineSpacing = 4 * s
let head = NSAttributedString(string: headline, attributes: [
    .font: NSFont.systemFont(ofSize: (isPad ? 60 : 80) * s, weight: .bold),
    .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
let sub = NSAttributedString(string: subline, attributes: [
    .font: NSFont.systemFont(ofSize: (isPad ? 34 : 44) * s, weight: .regular),
    .foregroundColor: NSColor.white.withAlphaComponent(0.88), .paragraphStyle: paragraph])
let margin = (isPad ? 160 : 90) * s
let textWidth = W - 2 * margin
let headRect = head.boundingRect(with: NSSize(width: textWidth, height: 10_000), options: [.usesLineFragmentOrigin])
let subRect = sub.boundingRect(with: NSSize(width: textWidth, height: 10_000), options: [.usesLineFragmentOrigin])
var cursor = H - (isPad ? 90 : 120) * s
head.draw(with: NSRect(x: margin, y: cursor - headRect.height, width: textWidth, height: headRect.height), options: [.usesLineFragmentOrigin])
cursor -= headRect.height + 22 * s
sub.draw(with: NSRect(x: margin, y: cursor - subRect.height, width: textWidth, height: subRect.height), options: [.usesLineFragmentOrigin])
cursor -= subRect.height + (isPad ? 50 : 64) * s

// The screen: scaled down, rounded, shadowed, cut off by the bottom edge.
let shotWidth = W * (isPad ? 0.80 : 0.84)
let shotHeight = shotWidth * H / W
let shotRect = CGRect(x: (W - shotWidth) / 2, y: cursor - shotHeight, width: shotWidth, height: shotHeight)
let radius = (isPad ? 36 : 150) * s * (shotWidth / W)
let path = CGPath(roundedRect: shotRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24 * s), blur: 70 * s, color: NSColor.black.withAlphaComponent(0.38).cgColor)
ctx.addPath(path)
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(path)
ctx.clip()
ctx.draw(shot, in: shotRect)
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: args[2]))
