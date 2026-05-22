import SwiftUI

/// Tiny utility to render pixel-art sprites from 2D color-index arrays.
/// Index 0 in any sprite means transparent.
struct PixelSprite: View {
    let pixels: [[Int]]
    let palette: [Color]
    let scale: CGFloat

    var body: some View {
        Canvas { context, _ in
            for (row, line) in pixels.enumerated() {
                for (col, idx) in line.enumerated() {
                    guard idx > 0, idx < palette.count else { continue }
                    let rect = CGRect(
                        x: CGFloat(col) * scale,
                        y: CGFloat(row) * scale,
                        width: scale + 0.5,
                        height: scale + 0.5
                    )
                    context.fill(Path(rect), with: .color(palette[idx]))
                }
            }
        }
        .frame(
            width: CGFloat(pixels.first?.count ?? 0) * scale,
            height: CGFloat(pixels.count) * scale
        )
        .drawingGroup()
    }
}

extension PixelSprite {
    /// Mirrors a sprite horizontally for facing-left renders.
    static func flippedHorizontally(_ pixels: [[Int]]) -> [[Int]] {
        pixels.map { $0.reversed() }
    }
}
