#!/usr/bin/env swift
import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/Resources"

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.2237

    // Background
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.13, alpha: 1).setFill()
    bg.fill()

    // Accent plate
    let inset = size * 0.14
    let plate = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let platePath = NSBezierPath(roundedRect: plate, xRadius: radius * 0.55, yRadius: radius * 0.55)
    NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.42, alpha: 1).setFill()
    platePath.fill()

    // Drive glyph (simplified)
    let driveW = size * 0.46
    let driveH = size * 0.30
    let driveX = (size - driveW) / 2
    let driveY = size * 0.38
    let drive = NSBezierPath(roundedRect: NSRect(x: driveX, y: driveY, width: driveW, height: driveH),
                             xRadius: size * 0.04, yRadius: size * 0.04)
    NSColor(calibratedRed: 0.18, green: 0.86, blue: 0.70, alpha: 1).setFill()
    drive.fill()

    // Slot
    let slot = NSBezierPath(roundedRect: NSRect(x: driveX + driveW * 0.18, y: driveY + driveH * 0.55,
                                                width: driveW * 0.64, height: driveH * 0.14),
                            xRadius: size * 0.02, yRadius: size * 0.02)
    NSColor(calibratedRed: 0.07, green: 0.22, blue: 0.20, alpha: 1).setFill()
    slot.fill()

    // Spark / clean mark
    let spark = NSBezierPath()
    let cx = size * 0.68
    let cy = size * 0.68
    let r = size * 0.07
    spark.move(to: NSPoint(x: cx, y: cy + r))
    spark.line(to: NSPoint(x: cx + r * 0.28, y: cy + r * 0.28))
    spark.line(to: NSPoint(x: cx + r, y: cy))
    spark.line(to: NSPoint(x: cx + r * 0.28, y: cy - r * 0.28))
    spark.line(to: NSPoint(x: cx, y: cy - r))
    spark.line(to: NSPoint(x: cx - r * 0.28, y: cy - r * 0.28))
    spark.line(to: NSPoint(x: cx - r, y: cy))
    spark.line(to: NSPoint(x: cx - r * 0.28, y: cy + r * 0.28))
    spark.close()
    NSColor.white.setFill()
    spark.fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
}

let iconset = outDir + "/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("diana.s@example.org", 32),
    ("icon_32x32.png", 32),
    ("ivan.p@example.net", 64),
    ("icon_128x128.png", 128),
    ("wendy.h@example.net", 256),
    ("icon_256x256.png", 256),
    ("wendy.h@example.net", 512),
    ("icon_512x512.png", 512),
    ("walt.e@example.net", 1024),
]

for (name, size) in sizes {
    writePNG(drawIcon(size: size), path: iconset + "/" + name)
}

let icns = outDir + "/AppIcon.icns"
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset, "-o", icns]
try proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("OK \(icns)")
} else {
    fputs("iconutil failed\n", stderr)
    exit(1)
}
