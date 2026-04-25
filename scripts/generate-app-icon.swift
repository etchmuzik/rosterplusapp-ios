// generate-app-icon.swift
//
// Renders the ROSTR+ brand icon at 1024×1024 (the single source size
// Xcode 14+ accepts) and writes it into RostrPlus/Assets.xcassets/
// AppIcon.appiconset/. App Store Connect handles down-scaling for
// every iOS variant.
//
// Run from repo root:
//   xcrun swift scripts/generate-app-icon.swift
//
// Re-run any time you tweak the design constants below.

import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: — Brand constants

let bg0      = NSColor(red: 8/255,    green: 9/255,    blue: 11/255,  alpha: 1)   // #08090b
let amber    = NSColor(red: 233/255,  green: 207/255,  blue: 146/255, alpha: 1)   // #e9cf92
let fg1      = NSColor(red: 0.96,     green: 0.96,     blue: 0.97,    alpha: 1)
let fg2      = NSColor(red: 0.78,     green: 0.78,     blue: 0.82,    alpha: 1)

// MARK: — Render

func drawIcon(into ctx: CGContext, size: CGFloat) {
    let pixelSize = CGSize(width: size, height: size)

    // Background — solid near-black.
    ctx.setFillColor(bg0.cgColor)
    ctx.fill(CGRect(origin: .zero, size: pixelSize))

    // Vertical highlight gradient.
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(white: 1, alpha: 0.06).cgColor,
            NSColor(white: 1, alpha: 0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: pixelSize.height),
        end: .zero,
        options: []
    )

    // Soft amber halo.
    let haloRadius = size * 0.55
    let halo = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            amber.withAlphaComponent(0.18).cgColor,
            amber.withAlphaComponent(0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        halo,
        startCenter: CGPoint(x: pixelSize.width / 2, y: pixelSize.height / 2),
        startRadius: 0,
        endCenter: CGPoint(x: pixelSize.width / 2, y: pixelSize.height / 2),
        endRadius: haloRadius,
        options: []
    )

    // Wordmark "R+".
    let glyphSize = size * 0.52
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "HelveticaNeue-Bold", size: glyphSize)
            ?? NSFont.boldSystemFont(ofSize: glyphSize),
        .foregroundColor: fg1,
        .kern: -size * 0.02
    ]
    let text = NSAttributedString(string: "R+", attributes: attrs)
    let textSize = text.size()
    let textRect = CGRect(
        x: (pixelSize.width - textSize.width) / 2,
        y: (pixelSize.height - textSize.height) / 2 - size * 0.02,
        width: textSize.width,
        height: textSize.height
    )
    text.draw(in: textRect)

    // Amber accent dot (brand verified pip).
    let dotSize = size * 0.06
    ctx.setFillColor(amber.cgColor)
    ctx.fillEllipse(in: CGRect(
        x: pixelSize.width - size * 0.16,
        y: size * 0.10,
        width: dotSize,
        height: dotSize
    ))
}

// MARK: — Write PNG

/// Render exactly `size`×`size` opaque PNG (no alpha — App Store
/// rejects alpha channel on AppIcon).
func writeOpaquePNG(size: CGFloat, to url: URL) throws {
    let pixelSize = Int(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: pixelSize * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        throw NSError(domain: "generate-app-icon", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Couldn't create CGContext"
        ])
    }

    // Push the AppKit drawing context onto our manually-built CGContext
    // so existing render code reuses NSColor / NSAttributedString.
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    drawIcon(into: ctx, size: CGFloat(pixelSize))
    NSGraphicsContext.restoreGraphicsState()

    guard
        let cgImage = ctx.makeImage(),
        let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.png" as CFString,
            1, nil
        )
    else {
        throw NSError(domain: "generate-app-icon", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Couldn't create image destination"
        ])
    }
    CGImageDestinationAddImage(dest, cgImage, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "generate-app-icon", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "PNG finalize failed"
        ])
    }
}

// MARK: — Main

let outputDir = URL(fileURLWithPath: "RostrPlus/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(
    at: outputDir,
    withIntermediateDirectories: true
)

let iconURL = outputDir.appendingPathComponent("AppIcon-1024.png")
try writeOpaquePNG(size: 1024, to: iconURL)
print("✓ Wrote \(iconURL.path)")

// Single-size Contents.json — Xcode 14+ + iOS 11+ accept just the
// 1024×1024 master and synthesise every other variant on App Store
// Connect's side.
let contentsJSON = """
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
let contentsURL = outputDir.appendingPathComponent("Contents.json")
try contentsJSON.data(using: .utf8)!.write(to: contentsURL)
print("✓ Wrote \(contentsURL.path)")
