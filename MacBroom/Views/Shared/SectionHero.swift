import SwiftUI

struct SectionHero: View {
    let item: SidebarItem
    let subtitle: String

    @AppStorage("macbroom.hackerMode") private var hackerMode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                iconBadge
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(titleGradient)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 14)

            rainbowDivider
        }
    }

    // MARK: - Title gradient

    private var titleGradient: LinearGradient {
        if hackerMode {
            return LinearGradient(
                colors: [Theme.hackerGreen, Theme.hackerGreen, Color(red: 0.5, green: 1.0, blue: 0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [item.tint, item.tint.opacity(0.7), Theme.stripeOrange.opacity(0.85)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Icon badge

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [item.tint.opacity(0.25), item.tint.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(item.tint.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: item.tint.opacity(0.25), radius: 12, x: 0, y: 4)
            Image(systemName: item.systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(item.tint)
        }
    }

    // MARK: - Rainbow divider

    private var rainbowDivider: some View {
        Group {
            if hackerMode {
                LinearGradient.hackerStripes.frame(height: 2)
            } else {
                LinearGradient.rainbow.frame(height: 2)
            }
        }
        .opacity(0.85)
    }
}
