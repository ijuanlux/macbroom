// Standalone script: renders the app icon at every macOS iconset size and writes PNGs.
// Run with:   swift Tools/generate_icon.swift
//
// Keep AppIconView in sync with MacBroom/Design/AppIconView.swift. Duplicated on purpose
// so this script doesn't depend on the app target.

import SwiftUI
import AppKit

// MARK: - Icon View (duplicate of AppIconView.swift)

struct AppIconView: View {
    let size: CGFloat
    init(size: CGFloat = 1024) { self.size = size }

    var body: some View {
        let cornerRadius = size * 0.225
        let appleWidth   = size * 0.58
        let appleHeight  = size * 0.65
        let appleCenterY = size * 0.06
        let leafSize     = size * 0.13

        ZStack {
            background(cornerRadius: cornerRadius)
            appleBody
                .frame(width: appleWidth, height: appleHeight)
                .offset(y: appleCenterY)
            leafShape
                .frame(width: leafSize * 0.60, height: leafSize * 1.15)
                .rotationEffect(.degrees(28))
                .offset(x: size * 0.045, y: appleCenterY - appleHeight / 2 - leafSize * 0.32)
            broom
                .frame(width: size * 0.25, height: size * 0.58)
                .offset(x: size * 0.33, y: size * 0.15)
        }
        .frame(width: size, height: size)
    }

    private func background(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.96, blue: 0.91),
                        Color(red: 0.96, green: 0.89, blue: 0.79)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.6), Color.clear],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: size * 0.012
                    )
            )
    }

    private var appleBody: some View {
        ZStack {
            AppleSilhouette()
                .fill(rainbowStripes)
            highlightBlob
            AppleSilhouette()
                .stroke(Color.black.opacity(0.18), lineWidth: size * 0.006)
        }
        .shadow(color: Color.black.opacity(0.18), radius: size * 0.018, x: 0, y: size * 0.012)
    }

    private var highlightBlob: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.45), Color.white.opacity(0)],
                    center: .center, startRadius: 0, endRadius: size * 0.08
                )
            )
            .frame(width: size * 0.18, height: size * 0.18)
            .offset(x: -size * 0.10, y: -size * 0.14)
    }

    private var rainbowStripes: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: stripeGreen,  location: 0.000),
                .init(color: stripeGreen,  location: 0.166),
                .init(color: stripeYellow, location: 0.167),
                .init(color: stripeYellow, location: 0.333),
                .init(color: stripeOrange, location: 0.334),
                .init(color: stripeOrange, location: 0.500),
                .init(color: stripeRed,    location: 0.501),
                .init(color: stripeRed,    location: 0.666),
                .init(color: stripePurple, location: 0.667),
                .init(color: stripePurple, location: 0.833),
                .init(color: stripeBlue,   location: 0.834),
                .init(color: stripeBlue,   location: 1.000),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var stripeGreen:  Color { Color(red: 0.40, green: 0.74, blue: 0.36) }
    private var stripeYellow: Color { Color(red: 0.98, green: 0.78, blue: 0.20) }
    private var stripeOrange: Color { Color(red: 0.96, green: 0.55, blue: 0.18) }
    private var stripeRed:    Color { Color(red: 0.91, green: 0.30, blue: 0.27) }
    private var stripePurple: Color { Color(red: 0.61, green: 0.34, blue: 0.71) }
    private var stripeBlue:   Color { Color(red: 0.18, green: 0.56, blue: 0.86) }

    private var leafShape: some View {
        LeafPath()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.36, green: 0.68, blue: 0.30),
                             Color(red: 0.25, green: 0.50, blue: 0.22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(LeafPath().stroke(Color.black.opacity(0.20), lineWidth: size * 0.005))
    }

    private var broom: some View {
        BroomGlyph()
    }
}

struct AppleSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cleft = CGPoint(x: w * 0.5, y: h * 0.10)
        p.move(to: cleft)
        p.addCurve(to: CGPoint(x: w, y: h * 0.42),
                   control1: CGPoint(x: w * 0.70, y: -h * 0.04),
                   control2: CGPoint(x: w * 1.02, y: h * 0.10))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h),
                   control1: CGPoint(x: w * 1.02, y: h * 0.86),
                   control2: CGPoint(x: w * 0.78, y: h * 1.04))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.42),
                   control1: CGPoint(x: w * 0.22, y: h * 1.04),
                   control2: CGPoint(x: -w * 0.02, y: h * 0.86))
        p.addCurve(to: cleft,
                   control1: CGPoint(x: -w * 0.02, y: h * 0.10),
                   control2: CGPoint(x: w * 0.30, y: -h * 0.04))
        p.closeSubpath()
        return p
    }
}

struct LeafPath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addQuadCurve(to: CGPoint(x: w / 2, y: h),
                       control: CGPoint(x: w * 1.10, y: h * 0.45))
        p.addQuadCurve(to: CGPoint(x: w / 2, y: 0),
                       control: CGPoint(x: -w * 0.10, y: h * 0.45))
        p.closeSubpath()
        return p
    }
}

struct BroomGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                handle(w: w, h: h)
                binding(w: w, h: h)
                bristles(w: w, h: h)
            }
        }
    }

    private func handle(w: CGFloat, h: CGFloat) -> some View {
        let handleSize = CGSize(width: w * 0.10, height: h * 0.55)
        let handlePos  = CGPoint(x: w * 0.5, y: h * 0.28)
        let fillGrad = LinearGradient(
            colors: [Color(red: 0.65, green: 0.42, blue: 0.20),
                     Color(red: 0.45, green: 0.27, blue: 0.10)],
            startPoint: .top, endPoint: .bottom)
        return ZStack {
            Capsule(style: .continuous)
                .fill(fillGrad)
                .frame(width: handleSize.width, height: handleSize.height)
                .position(handlePos)
            Capsule(style: .continuous)
                .stroke(Color.black.opacity(0.25), lineWidth: w * 0.005)
                .frame(width: handleSize.width, height: handleSize.height)
                .position(handlePos)
        }
    }

    private func binding(w: CGFloat, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: w * 0.015, style: .continuous)
            .fill(Color(red: 0.30, green: 0.18, blue: 0.08))
            .frame(width: w * 0.28, height: h * 0.05)
            .position(x: w * 0.5, y: h * 0.58)
    }

    private func bristles(w: CGFloat, h: CGFloat) -> some View {
        let bristleSize = CGSize(width: w * 0.65, height: h * 0.40)
        let position = CGPoint(x: w * 0.5, y: h * 0.81)
        return ZStack {
            BristleFan()
                .fill(LinearGradient(
                    colors: [Color(red: 0.98, green: 0.83, blue: 0.36),
                             Color(red: 0.80, green: 0.58, blue: 0.18)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: bristleSize.width, height: bristleSize.height)
                .position(position)
            BristleStrokes()
                .stroke(Color.black.opacity(0.25), lineWidth: w * 0.006)
                .frame(width: bristleSize.width, height: bristleSize.height)
                .position(position)
        }
    }
}

struct BristleFan: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.30, y: 0))
        p.addLine(to: CGPoint(x: w * 0.70, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: h),
                       control: CGPoint(x: w * 0.92, y: h * 0.55))
        p.addQuadCurve(to: CGPoint(x: 0, y: h),
                       control: CGPoint(x: w * 0.5, y: h * 1.08))
        p.addQuadCurve(to: CGPoint(x: w * 0.30, y: 0),
                       control: CGPoint(x: w * 0.08, y: h * 0.55))
        p.closeSubpath()
        return p
    }
}

struct BristleStrokes: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let lines = 11
        for i in 0..<lines {
            let t = CGFloat(i) / CGFloat(lines - 1)
            let topX = w * (0.30 + (0.70 - 0.30) * t)
            let bottomX = w * t
            p.move(to: CGPoint(x: topX, y: h * 0.05))
            p.addLine(to: CGPoint(x: bottomX, y: h * 0.98))
        }
        return p
    }
}

// MARK: - Renderer

@MainActor
func render() throws {
    let cwd = FileManager.default.currentDirectoryPath
    let outputDir = "\(cwd)/MacBroom/Resources/Assets.xcassets/AppIcon.appiconset"

    let outputs: [(filename: String, pointSize: CGFloat, scale: CGFloat)] = [
        ("icon_16x16.png",       16,  1),
        ("icon_16x16@2x.png",    16,  2),
        ("icon_32x32.png",       32,  1),
        ("icon_32x32@2x.png",    32,  2),
        ("icon_128x128.png",    128,  1),
        ("icon_128x128@2x.png", 128,  2),
        ("icon_256x256.png",    256,  1),
        ("icon_256x256@2x.png", 256,  2),
        ("icon_512x512.png",    512,  1),
        ("icon_512x512@2x.png", 512,  2),
    ]

    for entry in outputs {
        let pixelSize = entry.pointSize * entry.scale
        let view = AppIconView(size: pixelSize)
            .frame(width: pixelSize, height: pixelSize)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.isOpaque = true

        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            fputs("Failed to render \(entry.filename)\n", stderr)
            exit(1)
        }
        let url = URL(fileURLWithPath: "\(outputDir)/\(entry.filename)")
        try png.write(to: url)
        print("✓ \(entry.filename) (\(Int(pixelSize))×\(Int(pixelSize)))")
    }

    // Also overwrite Contents.json so every slot points to its file.
    let contents = #"""
    {
      "images" : [
        { "idiom" : "mac", "scale" : "1x", "size" : "16x16",   "filename" : "icon_16x16.png" },
        { "idiom" : "mac", "scale" : "2x", "size" : "16x16",   "filename" : "icon_16x16@2x.png" },
        { "idiom" : "mac", "scale" : "1x", "size" : "32x32",   "filename" : "icon_32x32.png" },
        { "idiom" : "mac", "scale" : "2x", "size" : "32x32",   "filename" : "icon_32x32@2x.png" },
        { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128x128.png" },
        { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_128x128@2x.png" },
        { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256x256.png" },
        { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_256x256@2x.png" },
        { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512x512.png" },
        { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_512x512@2x.png" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
    """#
    try contents.write(toFile: "\(outputDir)/Contents.json", atomically: true, encoding: .utf8)
    print("✓ Contents.json updated")
}

try await MainActor.run { try render() }
