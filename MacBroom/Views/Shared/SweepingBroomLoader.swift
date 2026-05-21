import SwiftUI

/// Replacement for ProgressView: a tiny broom sweeping back and forth with
/// rainbow bits fading underneath as it passes.
struct SweepingBroomLoader: View {
    var size: CGFloat = 28

    @State private var sweep: CGFloat = 0

    var body: some View {
        ZStack {
            bits
            broom
        }
        .frame(width: size * 1.4, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                sweep = 1
            }
        }
        .accessibilityLabel("Loading")
    }

    private var broom: some View {
        BroomGlyph()
            .frame(width: size * 0.46, height: size * 0.92)
            .rotationEffect(.degrees(sweepAngle), anchor: .top)
            .offset(x: sweepX, y: -size * 0.04)
    }

    private var bits: some View {
        let colors = Theme.rainbow
        return ForEach(0..<5, id: \.self) { i in
            let color = colors[i % colors.count]
            let x = size * (0.2 + CGFloat(i) * 0.25)
            let y = size * 0.82
            let dotSize = size * 0.10
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
                .position(x: x, y: y)
                .opacity(bitOpacity(index: i))
        }
    }

    // Broom moves from -25% to +25% of its container width.
    private var sweepX: CGFloat {
        -size * 0.28 + size * 0.56 * sweep
    }

    // Tilts -22° to +22° as it sweeps.
    private var sweepAngle: Double {
        -22 + 44 * Double(sweep)
    }

    /// Bit fades in/out depending on how close the broom is.
    private func bitOpacity(index: Int) -> Double {
        let t = Double(sweep)
        let bitT = Double(index) / 4.0
        let distance = abs(t - bitT)
        return max(0.15, 1.0 - distance * 2.5)
    }
}

#Preview {
    HStack(spacing: 32) {
        SweepingBroomLoader(size: 20)
        SweepingBroomLoader(size: 32)
        SweepingBroomLoader(size: 60)
    }
    .padding(40)
}
