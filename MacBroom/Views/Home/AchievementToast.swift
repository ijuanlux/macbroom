import SwiftUI

/// Pixel-flipper-style achievement unlock toast. Anchored top-center of Home.
struct AchievementToast: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(achievement.tint.opacity(0.25))
                    .frame(width: 48, height: 48)
                Image(systemName: achievement.systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(achievement.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("ACHIEVEMENT UNLOCKED")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .kerning(1.4)
                    .foregroundStyle(.white.opacity(0.75))
                Text(achievement.title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(achievement.blurb)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.80))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.16).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LinearGradient.rainbow, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
        .frame(maxWidth: 380)
    }
}

/// Small animated flame anchored beside the apple while a cleanup streak is
/// active. Pulses + slight rotation.
struct StreakFlame: View {
    let days: Int
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.85, blue: 0.15),
                                 Color(red: 0.95, green: 0.35, blue: 0.10)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .scaleEffect(pulse ? 1.15 : 0.95)
                .rotationEffect(.degrees(pulse ? 3 : -3))
                .shadow(color: Color(red: 0.95, green: 0.35, blue: 0.10).opacity(0.55), radius: 6)
            Text("\(days)d")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.10))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
