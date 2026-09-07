#!/usr/bin/env swift
// Rewrites a PNG without its alpha channel, composited on white.
// App Store Connect rejects an App Store icon that carries alpha.
//   swift Tools/flatten-icon.swift <in.png> <out.png>
import AppKit
let args = CommandLine.arguments
guard args.count == 3, let image = NSImage(contentsOfFile: args[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("usage: flatten-icon.swift <in.png> <out.png>\n", stderr); exit(1)
}
let w = cg.width, h = cg.height
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
let out = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: out)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: args[2]))
