#!/usr/bin/env swift
// Generates the DMG installer background (660x420 @1x and @2x).
// Renders a soft-warm background with brand, features, and an arrow
// pointing from the app icon to the Applications shortcut.

import AppKit
import CoreText

let width: CGFloat = 660
let height: CGFloat = 420

func renderBackground(scale: CGFloat) -> NSImage {
    let pxW = Int(width * scale)
    let pxH = Int(height * scale)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: pxW,
        height: pxH,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: scale, y: scale)

    // Background gradient (cream → warm cream)
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0.99, green: 0.96, blue: 0.91, alpha: 1),
            CGColor(red: 0.96, green: 0.89, blue: 0.79, alpha: 1)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: height),
        end: CGPoint(x: width, y: 0),
        options: []
    )

    // Top rainbow band (à la classic Apple)
    let rainbow: [CGColor] = [
        CGColor(red: 0.40, green: 0.74, blue: 0.36, alpha: 1),  // green
        CGColor(red: 0.98, green: 0.78, blue: 0.20, alpha: 1),  // yellow
        CGColor(red: 0.96, green: 0.55, blue: 0.18, alpha: 1),  // orange
        CGColor(red: 0.91, green: 0.30, blue: 0.27, alpha: 1),  // red
        CGColor(red: 0.61, green: 0.34, blue: 0.71, alpha: 1),  // purple
        CGColor(red: 0.18, green: 0.56, blue: 0.86, alpha: 1),  // blue
    ]
    let bandHeight: CGFloat = 6
    let stripeWidth = width / CGFloat(rainbow.count)
    for (i, color) in rainbow.enumerated() {
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: CGFloat(i) * stripeWidth,
                        y: height - bandHeight,
                        width: stripeWidth, height: bandHeight))
    }

    // Helper to draw text
    func drawText(_ s: String, x: CGFloat, y: CGFloat, font: NSFont,
                  color: NSColor, align: NSTextAlignment = .left) {
        let para = NSMutableParagraphStyle()
        para.alignment = align
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: para,
        ]
        let str = NSAttributedString(string: s, attributes: attrs)
        let line = CTLineCreateWithAttributedString(str)
        ctx.textPosition = CGPoint(x: x, y: height - y)
        CTLineDraw(line, ctx)
    }

    // Brand header
    drawText("MacBroom",
             x: 40, y: 64,
             font: NSFont.systemFont(ofSize: 32, weight: .bold),
             color: NSColor(red: 0.13, green: 0.09, blue: 0.05, alpha: 1))
    drawText("v0.5.0 · on-device AI · open-source mac cleaner",
             x: 42, y: 86,
             font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
             color: NSColor(red: 0.40, green: 0.35, blue: 0.30, alpha: 1))

    // Feature bullets
    let bullets: [(String, String, NSColor)] = [
        ("Ask MacBroom", "on-device AI assistant — 100% local, no cloud",
            NSColor(red: 0.40, green: 0.74, blue: 0.36, alpha: 1)),
        ("Smart Scan",   "caches · dev junk · large files · duplicates",
            NSColor(red: 0.18, green: 0.56, blue: 0.86, alpha: 1)),
        ("Uninstaller",  "apps + every leftover trace they leave behind",
            NSColor(red: 0.61, green: 0.34, blue: 0.71, alpha: 1)),
        ("Privacy",      "recent files, QuickLook thumbs, mail downloads",
            NSColor(red: 0.96, green: 0.55, blue: 0.18, alpha: 1)),
        ("Pixel mascot", "watches, sweeps, dances, breakdances, web-swings 🕸️",
            NSColor(red: 0.91, green: 0.30, blue: 0.27, alpha: 1)),
    ]
    var by: CGFloat = 130
    for (head, body, color) in bullets {
        // Color dot
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: 44, y: height - by - 2, width: 8, height: 8))
        drawText(head,
                 x: 60, y: by + 7,
                 font: NSFont.systemFont(ofSize: 13, weight: .bold),
                 color: NSColor(red: 0.13, green: 0.09, blue: 0.05, alpha: 1))
        drawText(body,
                 x: 145, y: by + 7,
                 font: NSFont.systemFont(ofSize: 12, weight: .regular),
                 color: NSColor(red: 0.40, green: 0.35, blue: 0.30, alpha: 1))
        by += 26
    }

    // Drag instruction in the middle bottom
    drawText("Drag MacBroom into the Applications folder →",
             x: width / 2, y: height - 50,
             font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
             color: NSColor(red: 0.13, green: 0.09, blue: 0.05, alpha: 1),
             align: .center)

    // Arrow between icon slots (icons positioned by Finder: app at ~180, apps at ~480, y=300)
    // Draw arrow shaft + head from x ~245 to x ~420 at y 300 (Finder coords; flip below)
    let arrowY = height - 300                  // Finder anchors are top-down
    let arrowStartX: CGFloat = 245
    let arrowEndX: CGFloat = 420

    ctx.setStrokeColor(NSColor(red: 0.40, green: 0.35, blue: 0.30, alpha: 0.55).cgColor)
    ctx.setLineWidth(3)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: arrowStartX, y: arrowY))
    ctx.addLine(to: CGPoint(x: arrowEndX - 10, y: arrowY))
    ctx.strokePath()
    // Arrow head
    ctx.setFillColor(NSColor(red: 0.40, green: 0.35, blue: 0.30, alpha: 0.55).cgColor)
    ctx.move(to: CGPoint(x: arrowEndX, y: arrowY))
    ctx.addLine(to: CGPoint(x: arrowEndX - 14, y: arrowY + 9))
    ctx.addLine(to: CGPoint(x: arrowEndX - 14, y: arrowY - 9))
    ctx.closePath()
    ctx.fillPath()

    // Footer credit
    drawText("github.com/ijuanlux/macbroom  ·  made with ♥",
             x: width / 2, y: 18,
             font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
             color: NSColor(red: 0.50, green: 0.45, blue: 0.40, alpha: 1),
             align: .center)

    let cgImg = ctx.makeImage()!
    let nsImg = NSImage(cgImage: cgImg, size: NSSize(width: width, height: height))
    return nsImg
}

func saveAsPNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("Failed to encode PNG\n", stderr); exit(1)
    }
    let url = URL(fileURLWithPath: path)
    try! png.write(to: url)
    print("Wrote \(path)")
}

let outDir = "build/dmg-assets"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let bg1x = renderBackground(scale: 1)
saveAsPNG(bg1x, to: "\(outDir)/background.png")

let bg2x = renderBackground(scale: 2)
saveAsPNG(bg2x, to: "\(outDir)/background@2x.png")
