import SwiftUI

struct SplashScreen: View {
    let onComplete: () -> Void

    // Animation state
    @State private var stripesProgress: CGFloat = -1.2    // -1.2 → 0 → +1.5 (off-left → covering → off-right)
    @State private var iconScale: CGFloat = 0
    @State private var iconRotation: Double = -180
    @State private var iconOpacity: Double = 0
    @State private var textVisible: Bool = false
    @State private var loaderVisible: Bool = false
    @State private var burstFire: Bool = false
    @State private var fadeOut: Bool = false

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()
            stripes
            ConfettiBurst(fire: $burstFire)
            content
        }
        .opacity(fadeOut ? 0 : 1)
        .onAppear { runIntro() }
    }

    // MARK: - Background

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.99, green: 0.96, blue: 0.91),
                     Color(red: 0.96, green: 0.89, blue: 0.79)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Sweeping stripes

    private var stripes: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { i in
                    let staggerExtra = CGFloat(i) * 0.06
                    Rectangle()
                        .fill(Theme.rainbow[i])
                        .frame(height: geo.size.height / 6)
                        .offset(x: stripesProgress * geo.size.width * (1.0 + staggerExtra))
                }
            }
        }
        .opacity(0.88)
    }

    // MARK: - Foreground content

    private var content: some View {
        VStack(spacing: 22) {
            AppIconView(size: 180)
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
                .scaleEffect(iconScale)
                .rotationEffect(.degrees(iconRotation))
                .opacity(iconOpacity)

            VStack(spacing: 8) {
                Text("MacBroom")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(titleGradient)
                Text("Sweeping your Mac clean")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.45, green: 0.40, blue: 0.35))
            }
            .opacity(textVisible ? 1 : 0)
            .offset(y: textVisible ? 0 : 12)

            SweepingBroomLoader(size: 56)
                .opacity(loaderVisible ? 1 : 0)
                .padding(.top, 8)
        }
    }

    private var titleGradient: LinearGradient {
        LinearGradient(colors: Theme.rainbow,
                       startPoint: .leading,
                       endPoint: .trailing)
    }

    // MARK: - Choreography

    private func runIntro() {
        // 0.00 → 0.55s: stripes sweep IN from left, covering the screen.
        withAnimation(.easeOut(duration: 0.55)) {
            stripesProgress = 0
        }

        // 0.55 → 1.05s: stripes sweep OUT to the right, revealing icon underneath.
        withAnimation(.easeIn(duration: 0.55).delay(0.55)) {
            stripesProgress = 1.6
        }

        // 0.70 → 1.30s: icon explodes in with spring + counter-rotation.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.70)) {
            iconScale = 1.0
            iconRotation = 0
            iconOpacity = 1
        }

        // 1.20s: confetti burst when icon settles
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            burstFire.toggle()
        }

        // 1.30 → 1.70s: title slides up + fades in
        withAnimation(.easeOut(duration: 0.4).delay(1.30)) {
            textVisible = true
        }

        // 1.60 → 2.00s: broom loader fades in
        withAnimation(.easeOut(duration: 0.3).delay(1.60)) {
            loaderVisible = true
        }

        // 2.80 → 3.30s: fade out the whole splash
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            withAnimation(.easeInOut(duration: 0.5)) {
                fadeOut = true
            }
            try? await Task.sleep(nanoseconds: 550_000_000)
            onComplete()
        }
    }
}

// MARK: - Confetti

/// Burst of colored particles flying outward from the center.
struct ConfettiBurst: View {
    @Binding var fire: Bool

    @State private var particles: [Particle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .offset(x: p.currentX, y: p.currentY)
                    .opacity(p.opacity)
            }
        }
        .onChange(of: fire) { _, _ in launch() }
    }

    private func launch() {
        particles = (0..<28).map { _ in Particle.random() }
        for index in particles.indices {
            let p = particles[index]
            withAnimation(.easeOut(duration: 0.9)) {
                particles[index].currentX = cos(p.angle) * p.distance
                particles[index].currentY = sin(p.angle) * p.distance
            }
            withAnimation(.easeIn(duration: 0.6).delay(0.4)) {
                particles[index].opacity = 0
            }
        }
    }

    struct Particle: Identifiable {
        let id = UUID()
        let color: Color
        let size: CGFloat
        let angle: Double
        let distance: CGFloat
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var opacity: Double = 1

        static func random() -> Particle {
            Particle(
                color: Theme.rainbow.randomElement()!,
                size: CGFloat.random(in: 4...11),
                angle: Double.random(in: 0...(.pi * 2)),
                distance: CGFloat.random(in: 90...230)
            )
        }
    }
}
