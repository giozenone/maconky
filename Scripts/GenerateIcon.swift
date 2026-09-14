#!/usr/bin/env swift
import AppKit

let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setFillColor(NSColor(red: 0.05, green: 0.07, blue: 0.08, alpha: 1).cgColor)
    let rounded = CGPath(roundedRect: rect.insetBy(dx: 80, dy: 80), cornerWidth: 220, cornerHeight: 220, transform: nil)
    ctx.addPath(rounded)
    ctx.fillPath()

    ctx.setStrokeColor(NSColor(red: 0.15, green: 0.90, blue: 0.78, alpha: 1).cgColor)
    ctx.setLineWidth(36)
    let ring = CGRect(x: 250, y: 250, width: 524, height: 524)
    ctx.strokeEllipse(in: ring)

    ctx.setLineWidth(22)
    ctx.strokeEllipse(in: ring.insetBy(dx: 70, dy: 70))

    ctx.setFillColor(NSColor(red: 0.15, green: 0.90, blue: 0.78, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: 472, y: 472, width: 80, height: 80))

    // Needle
    ctx.setStrokeColor(NSColor(red: 0.15, green: 0.90, blue: 0.78, alpha: 1).cgColor)
    ctx.setLineWidth(28)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 512, y: 512))
    ctx.addLine(to: CGPoint(x: 720, y: 700))
    ctx.strokePath()
    return true
}

let pngURL = outDir.appendingPathComponent("AppIcon.png")
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to encode icon PNG\n", stderr)
    exit(1)
}
try png.write(to: pngURL)
print("Wrote \(pngURL.path)")
