// Standalone script: renders a COLORED apple + broom on transparent background
// for the macOS menu bar. No rounded-square background chrome — just the silhouette
// so it sits cleanly next to other menu bar icons.
//
// Run: swift Tools/generate_menubar_icon.swift

import SwiftUI
import AppKit

// MARK: - Colored silhouette

struct MenuBarIcon: View {
    let size: CGFloat
    init(size: CGFloat) { self.size = size }

    var body: some View {
        ZStack {
            // Apple body with rainbow stripes — fills most of the canvas
            AppleSilhouetteShape()
                .fill(rainbow)
                .frame(width: size * 0.78, height: size * 0.84)
                .offset(x: -size * 0.05, y: size * 0.06)
                .overlay(
                    AppleSilhouetteShape()
                        .stroke(Color.black.opacity(0.25), lineWidth: max(0.5, size * 0.012))
                        .frame(width: size * 0.78, height: size * 0.84)
                        .offset(x: -size * 0.05, y: size * 0.06)
                )

            // Leaf — green, sitting on top of the apple
            LeafShape()
                .fill(LinearGradient(
                    colors: [Color(red: 0.42, green: 0.74, blue: 0.34),
                             Color(red: 0.25, green: 0.50, blue: 0.22)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.18, height: size * 0.26)
                .rotationEffect(.degrees(28))
                .offset(x: size * 0.00, y: -size * 0.32)

            // Broom: wooden handle + golden brush, peeking out the right side
            BroomGroup(size: size)
                .offset(x: size * 0.32, y: size * 0.14)
        }
        .frame(width: size, height: size)
    }

    private var rainbow: LinearGradient {
        LinearGradient(stops: [
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
        ], startPoint: .top, endPoint: .bottom)
    }

    private var stripeGreen:  Color { Color(red: 0.40, green: 0.74, blue: 0.36) }
    private var stripeYellow: Color { Color(red: 0.98, green: 0.78, blue: 0.20) }
    private var stripeOrange: Color { Color(red: 0.96, green: 0.55, blue: 0.18) }
    private var stripeRed:    Color { Color(red: 0.91, green: 0.30, blue: 0.27) }
    private var stripePurple: Color { Color(red: 0.61, green: 0.34, blue: 0.71) }
    private var stripeBlue:   Color { Color(red: 0.18, green: 0.56, blue: 0.86) }
}

// MARK: - Broom (colored)

struct BroomGroup: View {
    let size: CGFloat
    var body: some View {
        let handleColor = LinearGradient(
            colors: [Color(red: 0.65, green: 0.42, blue: 0.20),
                     Color(red: 0.42, green: 0.26, blue: 0.10)],
            startPoint: .top, endPoint: .bottom)
        let brushColor = LinearGradient(
            colors: [Color(red: 0.98, green: 0.83, blue: 0.36),
                     Color(red: 0.78, green: 0.55, blue: 0.16)],
            startPoint: .top, endPoint: .bottom)

        return ZStack {
            Capsule(style: .continuous)
                .fill(handleColor)
                .frame(width: size * 0.07, height: size * 0.34)
                .offset(y: -size * 0.10)

            BrushFanShape()
                .fill(brushColor)
                .frame(width: size * 0.26, height: size * 0.22)
                .offset(y: size * 0.16)
        }
    }
}

// MARK: - Shapes

struct AppleSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cleft = CGPoint(x: w * 0.5, y: h * 0.10)
        p.move(to: cleft)
        p.addCurve(to: CGPoint(x: w * 1.00, y: h * 0.27),
                   control1: CGPoint(x: w * 0.70, y: -h * 0.04),
                   control2: CGPoint(x: w * 1.02, y: h * 0.10))
        p.addArc(center: CGPoint(x: w * 1.00, y: h * 0.43),
                 radius: h * 0.16,
                 startAngle: .degrees(-90),
                 endAngle: .degrees(90),
                 clockwise: true)
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

struct LeafShape: Shape {
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

struct BrushFanShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w * 0.28, y: 0))
        p.addLine(to: CGPoint(x: w * 0.72, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: h),
                       control: CGPoint(x: w * 0.92, y: h * 0.55))
        p.addQuadCurve(to: CGPoint(x: 0, y: h),
                       control: CGPoint(x: w * 0.5, y: h * 1.10))
        p.addQuadCurve(to: CGPoint(x: w * 0.28, y: 0),
                       control: CGPoint(x: w * 0.08, y: h * 0.55))
        p.closeSubpath()
        return p
    }
}

// MARK: - Render

@MainActor
func render() throws {
    let cwd = FileManager.default.currentDirectoryPath
    let outputDir = "\(cwd)/MacBroom/Resources/Assets.xcassets/MenuBarIcon.imageset"

    let outputs: [(filename: String, pixelSize: CGFloat)] = [
        ("MenuBarIcon.png",    18),
        ("MenuBarIcon@2x.png", 36),
        ("MenuBarIcon@3x.png", 54),
    ]

    for entry in outputs {
        let view = MenuBarIcon(size: entry.pixelSize)
            .frame(width: entry.pixelSize, height: entry.pixelSize)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.isOpaque = false

        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            fputs("Failed to render \(entry.filename)\n", stderr)
            exit(1)
        }
        let url = URL(fileURLWithPath: "\(outputDir)/\(entry.filename)")
        try png.write(to: url)
        print("✓ \(entry.filename) (\(Int(entry.pixelSize))×\(Int(entry.pixelSize)))")
    }

    // Original rendering = keep colors as-is, no template tint.
    let contents = #"""
    {
      "images" : [
        { "idiom" : "universal", "scale" : "1x", "filename" : "MenuBarIcon.png" },
        { "idiom" : "universal", "scale" : "2x", "filename" : "MenuBarIcon@2x.png" },
        { "idiom" : "universal", "scale" : "3x", "filename" : "MenuBarIcon@3x.png" }
      ],
      "info" : { "author" : "xcode", "version" : 1 },
      "properties" : { "template-rendering-intent" : "original" }
    }
    """#
    try contents.write(toFile: "\(outputDir)/Contents.json", atomically: true, encoding: .utf8)
    print("✓ Contents.json updated (original/color mode)")
}

try await MainActor.run { try render() }
