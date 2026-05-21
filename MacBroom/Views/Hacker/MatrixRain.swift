import SwiftUI

/// Falling green characters effect — pure Canvas + TimelineView, GPU-friendly.
struct MatrixRain: View {
    var glyphSize: CGFloat = 14
    var columnSpacing: CGFloat = 18
    var trailLength: Int = 18

    private let charset: [Character] = Array(
        "01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモ$#%&*+=<>?@/\\!"
    )

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let columnCount = max(1, Int(size.width / columnSpacing))
                for col in 0..<columnCount {
                    drawColumn(col: col, t: t, size: size, context: &context)
                }
            }
        }
        .background(Color.black)
        .allowsHitTesting(false)
    }

    private func drawColumn(col: Int, t: TimeInterval, size: CGSize, context: inout GraphicsContext) {
        // Pseudo-randomize per column with prime moduli.
        let speed = 80.0 + Double((col * 37) % 50)              // px/sec
        let phaseOffset = Double((col * 73) % 400)
        let cycleLength = size.height + 200
        let headY = (t * speed + phaseOffset)
            .truncatingRemainder(dividingBy: Double(cycleLength)) - 100
        let x = CGFloat(col) * columnSpacing + columnSpacing / 2

        let count = charset.count
        for i in 0..<trailLength {
            let y = CGFloat(headY) - CGFloat(i) * glyphSize
            guard y > -glyphSize, y < size.height + glyphSize else { continue }
            let opacity = 1.0 - Double(i) / Double(trailLength)
            // Safe modulo that handles negatives without abs() (which traps on Int.min).
            let raw = col &* 17 &+ Int(y / glyphSize) &+ Int(t * 6)
            let charIndex = ((raw % count) + count) % count
            let ch = String(charset[charIndex])
            // The head is white-ish; trail fades from bright green to dark green.
            let color: Color = i == 0
                ? Color(red: 0.85, green: 1.0, blue: 0.9)
                : Color(red: 0.20, green: 0.95, blue: 0.35).opacity(opacity)
            var text = Text(ch).font(.system(size: glyphSize, weight: .bold, design: .monospaced))
            text = text.foregroundColor(color)
            context.draw(text, at: CGPoint(x: x, y: y))
        }
    }
}
