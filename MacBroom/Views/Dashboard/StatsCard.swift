import SwiftUI

struct StatsCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            stat(
                value: FileSystemUtils.formatBytes(appState.stats.totalReclaimed),
                label: "Total reclaimed",
                color: Theme.stripeGreen,
                systemImage: "arrow.down.circle.fill"
            )
            divider
            stat(
                value: "\(appState.stats.cleanupCount)",
                label: "Cleanups",
                color: Theme.stripeBlue,
                systemImage: "sparkles"
            )
            divider
            stat(
                value: "\(appState.stats.daysSinceFirstUse)",
                label: appState.stats.daysSinceFirstUse == 1 ? "Day with you" : "Days with you",
                color: Theme.stripePurple,
                systemImage: "calendar"
            )
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func stat(value: String, label: String, color: Color, systemImage: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 36)
    }
}
