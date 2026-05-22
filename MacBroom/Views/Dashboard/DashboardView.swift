import SwiftUI
import Charts

/// Pure-stats dashboard. No operational buttons — all sweeping happens via
/// the Home scene apple + chat. This view only renders numbers, charts and
/// trends so the user can read the state of their Mac at a glance.
struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var scanner = StorageScanner()
    @State private var memory: MemoryStats = .zero
    @State private var memoryTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .dashboard,
                subtitle: "Your Mac in numbers — read-only. Run cleanups from Home."
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroRow
                    chartsRow
                    ForecastBanner()
                    detailsRow
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 16)
            }
        }
        .task {
            if scanner.lastScanDate == nil {
                await scanner.scan()
            }
        }
        .onAppear { startMemoryTimer() }
        .onDisappear { memoryTimer?.invalidate() }
    }

    // MARK: - Hero stat row

    private var heroRow: some View {
        let columns = [GridItem(.adaptive(minimum: 200), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            heroStat(
                value: FileSystemUtils.formatBytes(appState.stats.totalReclaimed),
                label: "Total reclaimed",
                accent: Theme.stripeGreen,
                systemImage: "arrow.down.circle.fill"
            )
            heroStat(
                value: "\(appState.stats.cleanupCount)",
                label: "Cleanups",
                accent: Theme.stripeBlue,
                systemImage: "sparkles"
            )
            heroStat(
                value: FileSystemUtils.formatBytes(scanner.availableBytes),
                label: "Free space",
                accent: Theme.stripeOrange,
                systemImage: "internaldrive"
            )
            heroStat(
                value: "\(appState.stats.daysSinceFirstUse)",
                label: appState.stats.daysSinceFirstUse == 1 ? "Day with you" : "Days with you",
                accent: Theme.stripePurple,
                systemImage: "calendar"
            )
        }
    }

    private func heroStat(value: String, label: String, accent: Color, systemImage: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Charts row (storage donut + activity bars)

    private var chartsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            storageDonutCard
                .frame(maxWidth: .infinity)
            activityCard
                .frame(maxWidth: .infinity)
        }
    }

    private var storageDonutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader("Storage breakdown", subtitle: storageSubtitle)
            HStack(alignment: .center, spacing: 18) {
                donutChart
                    .frame(width: 150, height: 150)
                donutLegend
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardChrome()
    }

    private var storageSubtitle: String {
        guard scanner.totalBytes > 0 else { return "Measuring…" }
        let pct = Int((Double(scanner.usedBytes) / Double(scanner.totalBytes) * 100).rounded())
        return "\(pct)% used · \(FileSystemUtils.formatBytes(scanner.totalBytes)) total"
    }

    @ViewBuilder
    private var donutChart: some View {
        let positive = scanner.usages.filter { $0.sizeBytes > 0 }
        let avail = max(0, scanner.availableBytes)
        if scanner.totalBytes == 0 {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 18)
                SweepingBroomLoader(size: 36)
            }
        } else {
            Chart {
                ForEach(positive) { usage in
                    SectorMark(
                        angle: .value("Bytes", usage.sizeBytes),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(usage.category.color)
                }
                if avail > 0 {
                    SectorMark(
                        angle: .value("Available", avail),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(Color.primary.opacity(0.10))
                }
            }
            .chartLegend(.hidden)
            .overlay {
                VStack(spacing: 0) {
                    Text(FileSystemUtils.formatBytes(scanner.usedBytes))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("used")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var donutLegend: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(scanner.usages) { usage in
                legendRow(color: usage.category.color,
                          label: usage.category.rawValue,
                          value: FileSystemUtils.formatBytes(usage.sizeBytes))
            }
            legendRow(color: Color.primary.opacity(0.18),
                      label: "Available",
                      value: FileSystemUtils.formatBytes(scanner.availableBytes))
        }
    }

    private func legendRow(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11, weight: .medium))
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var activityCard: some View {
        let history = appState.stats.last30Days()
        let totalLast30 = history.reduce(0) { $0 + $1.bytes }
        let peak = history.map(\.bytes).max() ?? 0
        let peakDay = history.first(where: { $0.bytes == peak })?.day
        return VStack(alignment: .leading, spacing: 14) {
            cardHeader("Last 30 days", subtitle: "\(FileSystemUtils.formatBytes(totalLast30)) reclaimed")
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
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .font(.system(size: 9))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 150)

            HStack(spacing: 14) {
                miniMetric(label: "Peak day",
                           value: peak > 0 ? FileSystemUtils.formatBytes(peak) : "—")
                if let peakDay {
                    miniMetric(label: "On",
                               value: peakDay.formatted(.dateTime.day().month(.abbreviated)))
                }
                miniMetric(label: "Avg / day",
                           value: FileSystemUtils.formatBytes(totalLast30 / 30))
                Spacer(minLength: 0)
            }
        }
        .cardChrome()
    }

    private func miniMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .kerning(0.8)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Details row (records + streak + memory pulse)

    private var detailsRow: some View {
        let columns = [GridItem(.adaptive(minimum: 260), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12, content: {
            recordsCard
            streakCard
            memoryPulseCard
        })
    }

    private var recordsCard: some View {
        let history = appState.stats.last30Days()
        let biggest = history.map(\.bytes).max() ?? 0
        let totalDone = appState.stats.cleanupCount
        let avg = totalDone > 0 ? appState.stats.totalReclaimed / Int64(totalDone) : 0
        let lastDate = appState.stats.lastCleanupDate
        return VStack(alignment: .leading, spacing: 12) {
            cardHeader("Records", subtitle: nil, accent: Theme.stripeYellow, systemImage: "trophy.fill")
            metricRow(label: "Biggest day", value: biggest > 0 ? FileSystemUtils.formatBytes(biggest) : "—")
            metricRow(label: "Avg cleanup", value: avg > 0 ? FileSystemUtils.formatBytes(avg) : "—")
            metricRow(label: "Last cleanup",
                      value: lastDate.map { $0.formatted(.relative(presentation: .named)) } ?? "never")
        }
        .cardChrome()
    }

    private var streakCard: some View {
        let streak = computeStreak()
        let busyDays = appState.stats.last30Days().filter { $0.bytes > 0 }.count
        return VStack(alignment: .leading, spacing: 12) {
            cardHeader("Habit", subtitle: nil, accent: Theme.stripeOrange, systemImage: "flame.fill")
            metricRow(label: "Current streak",
                      value: streak == 1 ? "1 day" : "\(streak) days")
            metricRow(label: "Active days / 30", value: "\(busyDays)")
            metricRow(label: "First use",
                      value: appState.stats.firstUseDate.formatted(.dateTime.day().month(.abbreviated).year()))
        }
        .cardChrome()
    }

    private var memoryPulseCard: some View {
        let usedRatio = memory.total > 0 ? Double(memory.usedApps) / Double(memory.total) : 0
        return VStack(alignment: .leading, spacing: 12) {
            cardHeader("Memory", subtitle: nil, accent: Theme.stripeRed, systemImage: "memorychip.fill")
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(FileSystemUtils.formatBytes(memory.usedApps))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("/ \(FileSystemUtils.formatBytes(memory.total))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.10))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.stripeGreen, Theme.stripeYellow, Theme.stripeRed],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(1, usedRatio))
                    }
                }
                .frame(height: 8)
            }
            metricRow(label: "Wired", value: FileSystemUtils.formatBytes(memory.wired))
            metricRow(label: "Compressed", value: FileSystemUtils.formatBytes(memory.compressed))
        }
        .cardChrome()
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Helpers

    private func cardHeader(_ title: String, subtitle: String?, accent: Color? = nil, systemImage: String? = nil) -> some View {
        HStack(spacing: 8) {
            if let systemImage, let accent {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func startMemoryTimer() {
        memory = MemoryReader.current()
        memoryTimer?.invalidate()
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in memory = MemoryReader.current() }
        }
    }

    /// Counts consecutive days (ending today or yesterday) with at least one cleanup.
    private func computeStreak() -> Int {
        let days = appState.stats.last30Days().reversed()    // newest first
        var streak = 0
        for entry in days {
            if entry.bytes > 0 { streak += 1 }
            else if streak == 0 { continue }                  // allow today empty
            else { break }
        }
        return streak
    }
}

private extension View {
    func cardChrome() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}
