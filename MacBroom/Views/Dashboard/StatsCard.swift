import SwiftUI
import Charts

struct StatsCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
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

            Divider().opacity(0.4)

            chartSection
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var chartSection: some View {
        let history = appState.stats.last30Days()
        let totalLast30 = history.reduce(0) { $0 + $1.bytes }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last 30 days")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(FileSystemUtils.formatBytes(totalLast30))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Chart(history) { entry in
                BarMark(
                    x: .value("Day", entry.day, unit: .day),
                    y: .value("Bytes", entry.bytes)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.stripeGreen, Theme.stripeBlue],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine().foregroundStyle(.clear)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .font(.system(size: 9))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 70)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
