#!/usr/bin/env swift
// Generates the Cineo app icons from `film.stack.fill` SF Symbol.
// Run: swift Tools/generate_app_icon.swift
//
// Produces every PNG referenced by AppIcon.appiconset's Contents.json
// (iOS 1024 light/dark/tinted + all macOS sizes).

import AppKit
import Foundation

let projectRoot = FileManager.default.currentDirectoryPath
let outDir = "\(projectRoot)/Cineo/Assets.xcassets/AppIcon.appiconset"

func render(size: CGFloat,
            background: NSColor,
            symbolColor: NSColor,
            fileName: String,
            symbolFraction: CGFloat = 0.62,
            background2: NSColor? = nil) {
    let pixelSize = NSSize(width: size, height: size)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else { return }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Background — radial gradient from a slightly warmer center to the
    // requested base color, mirroring the in-app background glow.
    let center = CGPoint(x: pixelSize.width * 0.5, y: pixelSize.height * 0.78)
    let radius = pixelSize.width * 0.85
    let centerColor = background2 ?? background.blended(withFraction: 0.5,
                                                        of: NSColor(srgbRed: 0.18, green: 0.10, blue: 0.04, alpha: 1.0)) ?? background

    let cs = CGColorSpaceCreateDeviceRGB()
    let colors = [centerColor.cgColor, background.cgColor] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]
    if let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: locations) {
        background.setFill()
        NSRect(origin: .zero, size: pixelSize).fill()
        ctx.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: radius,
            options: []
        )
    }

    // Foreground symbol
    let symbolPointSize = size * symbolFraction
    let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .bold)
    if let baseSymbol = NSImage(systemSymbolName: "film.stack.fill",
                                accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        baseSymbol.isTemplate = true
        let tinted = NSImage(size: baseSymbol.size, flipped: false) { rect in
            symbolColor.set()
            baseSymbol.draw(in: rect)
            rect.fill(using: .sourceAtop)
            return true
        }

        let drawRect = NSRect(
            x: (pixelSize.width - tinted.size.width) / 2,
            y: (pixelSize.height - tinted.size.height) / 2,
            width: tinted.size.width,
            height: tinted.size.height
        )

        // Soft golden glow behind the symbol
        ctx.saveGState()
        ctx.setShadow(
            offset: .zero,
            blur: size * 0.06,
            color: symbolColor.withAlphaComponent(0.55).cgColor
        )
        tinted.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        ctx.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("failed to encode \(fileName)\n".utf8))
        return
    }
    let url = URL(fileURLWithPath: "\(outDir)/\(fileName)")
    try? png.write(to: url)
    print("  wrote \(fileName) (\(Int(size))×\(Int(size)))")
}

let darkBackground = NSColor(srgbRed: 7/255.0, green: 8/255.0, blue: 12/255.0, alpha: 1.0)
let gold = NSColor(srgbRed: 255/255.0, green: 198/255.0, blue: 90/255.0, alpha: 1.0)
let goldLight = NSColor(srgbRed: 255/255.0, green: 224/255.0, blue: 138/255.0, alpha: 1.0)

let macSizes: [(label: String, size: CGFloat)] = [
    ("16",   16),
    ("16@2x", 32),
    ("32",   32),
    ("32@2x", 64),
    ("128",  128),
    ("128@2x", 256),
    ("256",  256),
    ("256@2x", 512),
    ("512",  512),
    ("512@2x", 1024),
]

print("Writing icons to \(outDir)")

// iOS — light (default), dark, tinted. All 1024×1024.
render(size: 1024, background: darkBackground, symbolColor: gold,
       fileName: "AppIcon-iOS-light-1024.png")

render(size: 1024, background: NSColor.black, symbolColor: gold,
       fileName: "AppIcon-iOS-dark-1024.png",
       background2: NSColor(srgbRed: 0.06, green: 0.04, blue: 0.02, alpha: 1.0))

// Tinted: monochrome-friendly. iOS recolors the foreground at runtime,
// so we render a clean white symbol on transparent (background uses a
// deep neutral so the asset survives systems that don't recolor).
render(size: 1024, background: NSColor.black, symbolColor: NSColor.white,
       fileName: "AppIcon-iOS-tinted-1024.png",
       background2: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1.0))

// macOS sizes
for (label, size) in macSizes {
    render(size: size, background: darkBackground, symbolColor: gold,
           fileName: "AppIcon-mac-\(label).png")
}

print("done")
