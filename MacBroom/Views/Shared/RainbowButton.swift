import SwiftUI

/// Big rainbow gradient CTA — used for "Smart Scan" / "Clean all" / hero actions.
struct RainbowButton: View {
    let title: String
    let systemImage: String?
    let isLoading: Bool
    let action: () -> Void

    @AppStorage("macbroom.hackerMode") private var hackerMode: Bool = false
    @State private var isHovering = false
    @State private var shimmer: CGFloat = -1

    init(_ title: String,
         systemImage: String? = nil,
         isLoading: Bool = false,
         action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    SweepingBroomLoader(size: 22)
                        .colorInvert()
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(background)
            .overlay(shimmerOverlay)
            .clipShape(Capsule())
            .shadow(color: (hackerMode ? Theme.hackerGreen : Theme.stripeOrange).opacity(0.45), radius: 14, x: 0, y: 6)
            .scaleEffect(isHovering ? 1.025 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmer = 2
            }
        }
    }

    private var background: some View {
        LinearGradient(colors: hackerMode ? Theme.hackerStripes : Theme.rainbow,
                       startPoint: .leading,
                       endPoint: .trailing)
    }

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, .white.opacity(0.35), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.35)
            .offset(x: geo.size.width * shimmer)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    VStack(spacing: 24) {
        RainbowButton("Smart Scan", systemImage: "sparkles") { }
        RainbowButton("Clean 1,23 GB", systemImage: "trash") { }
        RainbowButton("Scanning…", isLoading: true) { }
    }
    .padding(40)
    .frame(width: 400)
}
