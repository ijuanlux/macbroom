import SwiftUI

struct ForecastBanner: View {
    @ObservedObject private var trend = DiskTrendStore.shared
    @State private var forecast: DiskForecast?

    var body: some View {
        Group {
            if let forecast {
                content(forecast: forecast)
            } else {
                empty
            }
        }
        .onAppear {
            trend.snapshotIfNeeded()
            forecast = trend.forecast()
        }
    }

    private func content(forecast: DiskForecast) -> some View {
        let perDay = abs(forecast.bytesPerDay)
        let fillingUp = forecast.bytesPerDay > 0
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill((fillingUp ? Theme.stripeOrange : Theme.stripeGreen).opacity(0.20))
                    .frame(width: 38, height: 38)
                Image(systemName: fillingUp ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(fillingUp ? Theme.stripeOrange : Theme.stripeGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let days = forecast.daysUntilFull, fillingUp {
                    Text("At this rate your disk fills in \(days) days")
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Text("You're freeing space — keep going")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("\(FileSystemUtils.formatBytes(perDay)) per day · based on last \(forecast.lookbackDays) days")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var empty: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Building disk trend")
                    .font(.system(size: 14, weight: .semibold))
                Text("MacBroom samples free space once a day. Forecasts kick in after 3+ days of data.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
