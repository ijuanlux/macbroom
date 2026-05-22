import SwiftUI

/// Vintage CRT television sitting on the floor of the Home scene. Cycles
/// between fake Neo Geo-style mini-game animations every few seconds so the
/// scene feels alive. Pure SwiftUI shapes — no assets.
struct NeoGeoTV: View {
    @State private var gameIndex: Int = 0
    @State private var animFrame: Int = 0
    @State private var gameTimer: Timer?
    @State private var frameTimer: Timer?

    private let bezelBrown = Color(red: 0.20, green: 0.14, blue: 0.08)
    private let bezelDark  = Color(red: 0.12, green: 0.08, blue: 0.04)
    private let knobBrown  = Color(red: 0.45, green: 0.32, blue: 0.20)

    private let screenSize: CGSize = CGSize(width: 78, height: 58)
    private let games = 4

    var body: some View {
        ZStack(alignment: .top) {
            antenna
                .offset(y: -34)
            tvBody
        }
        .frame(width: 96, height: 122)
        .shadow(color: .black.opacity(0.30), radius: 4, y: 3)
        .onAppear { start() }
        .onDisappear {
            gameTimer?.invalidate()
            frameTimer?.invalidate()
        }
    }

    private var antenna: some View {
        Path { p in
            p.move(to: CGPoint(x: 36, y: 30))
            p.addLine(to: CGPoint(x: 14, y: 0))
            p.move(to: CGPoint(x: 60, y: 30))
            p.addLine(to: CGPoint(x: 82, y: 0))
        }
        .stroke(bezelDark, lineWidth: 2)
        .frame(width: 96, height: 34)
        .overlay(
            HStack(spacing: 60) {
                Circle().fill(bezelDark).frame(width: 4, height: 4)
                Circle().fill(bezelDark).frame(width: 4, height: 4)
            }
            .frame(width: 96, height: 34, alignment: .top)
        )
    }

    private var tvBody: some View {
        ZStack {
            // Outer bezel
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(bezelBrown)
                .frame(width: 96, height: 90)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(bezelDark, lineWidth: 2)
                .frame(width: 96, height: 90)

            VStack(spacing: 5) {
                // Screen with inner shadow
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: screenSize.width, height: screenSize.height)
                    gameContent
                        .frame(width: screenSize.width, height: screenSize.height)
                        .clipped()
                    // Scanlines
                    VStack(spacing: 1) {
                        ForEach(0..<Int(screenSize.height / 2), id: \.self) { _ in
                            Color.black.opacity(0.22).frame(height: 1)
                            Color.clear.frame(height: 1)
                        }
                    }
                    .frame(width: screenSize.width, height: screenSize.height)
                    // CRT vignette
                    RadialGradient(
                        colors: [Color.clear, Color.clear, Color.black.opacity(0.45)],
                        center: .center, startRadius: 8, endRadius: 50
                    )
                    .frame(width: screenSize.width, height: screenSize.height)
                    Rectangle()
                        .strokeBorder(bezelDark, lineWidth: 2)
                        .frame(width: screenSize.width, height: screenSize.height)
                }
                .allowsHitTesting(false)

                // Controls strip
                HStack(spacing: 6) {
                    Circle().fill(knobBrown).frame(width: 5, height: 5)
                    Circle().fill(knobBrown).frame(width: 5, height: 5)
                    Rectangle().fill(knobBrown).frame(width: 14, height: 3).cornerRadius(1)
                    Spacer(minLength: 4)
                    Circle()
                        .fill(Color(red: 0.95, green: 0.20, blue: 0.18))
                        .frame(width: 4, height: 4)
                        .shadow(color: Color(red: 0.95, green: 0.20, blue: 0.18).opacity(0.7), radius: 2)
                }
                .padding(.horizontal, 8)
                .frame(width: 96, alignment: .leading)
            }
        }
    }

    // MARK: - Game cycling

    private func start() {
        // Cycle game scene every 6 seconds
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.25)) {
                    gameIndex = (gameIndex + 1) % games
                    animFrame = 0
                }
            }
        }
        // Advance per-frame animation every 0.18s
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { _ in
            Task { @MainActor in animFrame &+= 1 }
        }
    }

    @ViewBuilder
    private var gameContent: some View {
        switch gameIndex {
        case 0: metalSlugScene
        case 1: pacmanScene
        case 2: kofScene
        default: racerScene
        }
    }

    // MARK: - Game scenes

    /// Soldier running across a desert with occasional muzzle flash.
    private var metalSlugScene: some View {
        let bgTop = Color(red: 0.95, green: 0.55, blue: 0.20)
        let bgMid = Color(red: 0.90, green: 0.35, blue: 0.15)
        let sand  = Color(red: 0.60, green: 0.45, blue: 0.20)
        let xPos = CGFloat((animFrame * 4) % Int(screenSize.width + 30)) - 15
        let bob = CGFloat((animFrame % 2) * 2)
        return ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                LinearGradient(colors: [bgTop, bgMid], startPoint: .top, endPoint: .bottom)
                Rectangle().fill(sand)
                    .frame(height: 14)
            }
            // Sun
            Circle().fill(Color(red: 0.99, green: 0.92, blue: 0.30))
                .frame(width: 12, height: 12).offset(x: 6, y: 6)
            // Soldier (head + body + gun)
            ZStack {
                Rectangle().fill(Color(red: 0.30, green: 0.45, blue: 0.30))
                    .frame(width: 6, height: 9)
                    .offset(y: -3)
                Circle().fill(Color(red: 0.85, green: 0.70, blue: 0.50))
                    .frame(width: 4, height: 4)
                    .offset(y: -10)
                Rectangle().fill(Color.black).frame(width: 9, height: 2).offset(x: 5, y: -5)
                // Muzzle flash on alternate frames
                if animFrame.isMultiple(of: 3) {
                    Circle().fill(Color(red: 1.0, green: 0.85, blue: 0.20))
                        .frame(width: 5, height: 5)
                        .offset(x: 11, y: -5)
                        .shadow(color: Color.yellow, radius: 3)
                }
            }
            .offset(x: xPos, y: 22 + bob)
            // Score HUD
            Text("1P  003200")
                .font(.system(size: 5, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .offset(x: 3, y: 1)
                .frame(width: screenSize.width, height: screenSize.height, alignment: .topLeading)
        }
    }

    /// Yellow Pac eating a row of dots while a ghost trails behind.
    private var pacmanScene: some View {
        let xPac = CGFloat((animFrame * 5) % Int(screenSize.width + 20)) - 10
        let xGhost = xPac - 18
        return ZStack {
            Color.black
            // Dot row
            HStack(spacing: 6) {
                ForEach(0..<10, id: \.self) { _ in
                    Circle().fill(Color(red: 0.99, green: 0.85, blue: 0.50))
                        .frame(width: 3, height: 3)
                }
            }
            .offset(y: -2)
            // Pac
            PacShape(open: animFrame.isMultiple(of: 2))
                .fill(Color(red: 0.99, green: 0.85, blue: 0.10))
                .frame(width: 12, height: 12)
                .offset(x: xPac - screenSize.width / 2, y: -2)
            // Ghost
            ZStack {
                GhostBody()
                    .fill(Color(red: 0.92, green: 0.20, blue: 0.20))
                    .frame(width: 10, height: 11)
                HStack(spacing: 1) {
                    Circle().fill(.white).frame(width: 2.5, height: 2.5)
                    Circle().fill(.white).frame(width: 2.5, height: 2.5)
                }
                .offset(y: -2)
            }
            .offset(x: xGhost - screenSize.width / 2, y: -2)
            Text("HI: 9999")
                .font(.system(size: 5, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .offset(x: 3, y: 1)
                .frame(width: screenSize.width, height: screenSize.height, alignment: .topLeading)
        }
    }

    /// Two pixel fighters punching alternately on a stage.
    private var kofScene: some View {
        let bg = Color(red: 0.18, green: 0.10, blue: 0.30)
        let leftPunch = animFrame.isMultiple(of: 2)
        return ZStack(alignment: .bottom) {
            bg
            // Sky lights
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(Color.white.opacity(Double((animFrame + i) % 3 == 0 ? 0.9 : 0.3)))
                    .frame(width: 2, height: 2)
                    .offset(x: CGFloat(i * 14 - 28), y: 6)
                    .frame(width: screenSize.width, height: screenSize.height, alignment: .top)
            }
            // Floor
            Rectangle().fill(Color(red: 0.45, green: 0.30, blue: 0.15)).frame(height: 6)
            // Left fighter
            FighterShape(armOut: leftPunch, color: Color(red: 0.92, green: 0.30, blue: 0.20))
                .frame(width: 14, height: 22)
                .offset(x: -18, y: -6)
            // Right fighter (mirrored)
            FighterShape(armOut: !leftPunch, color: Color(red: 0.18, green: 0.50, blue: 0.85))
                .frame(width: 14, height: 22)
                .scaleEffect(x: -1, y: 1)
                .offset(x: 18, y: -6)
            // Hit flash mid-stage on alternate frames
            if animFrame.isMultiple(of: 3) {
                Image(systemName: "burst.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color(red: 0.99, green: 0.92, blue: 0.20))
                    .offset(y: -14)
            }
            Text("KOF")
                .font(.system(size: 6, weight: .black, design: .serif))
                .foregroundStyle(Color(red: 0.99, green: 0.20, blue: 0.20))
                .offset(x: 4, y: 1)
                .frame(width: screenSize.width, height: screenSize.height, alignment: .topLeading)
        }
    }

    /// Retro top-down racer — yellow car dodging obstacles on a moving track.
    private var racerScene: some View {
        let yScroll = CGFloat((animFrame * 6) % 12)
        return ZStack {
            // Grass
            Color(red: 0.20, green: 0.55, blue: 0.30)
            // Road
            Rectangle()
                .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                .frame(width: 38)
            // Dashed centre line (animated)
            VStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { _ in
                    Rectangle().fill(Color.white).frame(width: 3, height: 6)
                }
            }
            .offset(y: yScroll)
            // Player car
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.99, green: 0.85, blue: 0.20))
                    .frame(width: 10, height: 16)
                Rectangle().fill(Color.black).frame(width: 6, height: 3).offset(y: -4)
                Rectangle().fill(Color.black).frame(width: 6, height: 3).offset(y: 4)
            }
            .offset(x: animFrame.isMultiple(of: 4) ? -3 : 3, y: 8)
            // Oncoming car
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.92, green: 0.20, blue: 0.18))
                .frame(width: 10, height: 16)
                .offset(x: animFrame.isMultiple(of: 3) ? 8 : -8,
                        y: CGFloat((animFrame * 6) % 40) - 25)
            Text("LAP 02")
                .font(.system(size: 5, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .offset(x: 3, y: 1)
                .frame(width: screenSize.width, height: screenSize.height, alignment: .topLeading)
        }
    }
}

// MARK: - Helper shapes

private struct PacShape: Shape {
    let open: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mouthAngle: Double = open ? 40 : 6
        p.move(to: CGPoint(x: rect.midX, y: rect.midY))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width / 2,
                 startAngle: .degrees(mouthAngle),
                 endAngle: .degrees(360 - mouthAngle),
                 clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct GhostBody: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let r = w / 2
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addArc(center: CGPoint(x: r, y: r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.85))
        p.addLine(to: CGPoint(x: w * 0.50, y: h))
        p.addLine(to: CGPoint(x: w * 0.25, y: h * 0.85))
        p.closeSubpath()
        return p
    }
}

private struct FighterShape: View {
    let armOut: Bool
    let color: Color
    var body: some View {
        ZStack(alignment: .top) {
            // Head
            Circle().fill(Color(red: 0.92, green: 0.78, blue: 0.55))
                .frame(width: 7, height: 7)
            // Body
            Rectangle().fill(color)
                .frame(width: 8, height: 11)
                .offset(y: 6)
            // Arm
            Rectangle().fill(Color(red: 0.92, green: 0.78, blue: 0.55))
                .frame(width: armOut ? 9 : 4, height: 2)
                .offset(x: armOut ? 6 : 2, y: 8)
            // Legs
            Rectangle().fill(color).frame(width: 3, height: 5).offset(x: -2, y: 17)
            Rectangle().fill(color).frame(width: 3, height: 5).offset(x: 2, y: 17)
        }
    }
}
