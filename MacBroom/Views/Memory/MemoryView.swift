import SwiftUI

struct MemoryView: View {
    @State private var stats: MemoryStats = .zero
    @State private var isPurging: Bool = false
    @State private var lastResult: String?

    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .memory,
                subtitle: "Live RAM usage breakdown. Free inactive pages with one click."
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    breakdownCard
                    actionCard
                }
                .padding(24)
            }
        }
        .onAppear { stats = MemoryReader.current() }
        .onReceive(refresh) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                stats = MemoryReader.current()
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(spacing: 0) {
            stat(label: "Total",      value: FileSystemUtils.formatBytes(stats.total), color: SidebarItem.memory.tint)
            divider
            stat(label: "Used apps",  value: FileSystemUtils.formatBytes(stats.usedApps), color: Theme.stripeOrange)
            divider
            stat(label: "Compressed", value: FileSystemUtils.formatBytes(stats.compressed), color: Theme.stripePurple)
            divider
            stat(label: "Free",       value: FileSystemUtils.formatBytes(stats.free), color: Theme.stripeGreen)
        }
        .padding(.vertical, 14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func stat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 30)
    }

    // MARK: - Breakdown

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Breakdown")
                .font(.system(size: 14, weight: .semibold))
            stackedBar
            legend
        }
        .padding(20)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var stackedBar: some View {
        GeometryReader { geo in
            let total = max(1, stats.total)
            HStack(spacing: 1) {
                segment(width: geo.size.width * CGFloat(Double(stats.active)     / Double(total)), color: Theme.stripeRed)
                segment(width: geo.size.width * CGFloat(Double(stats.wired)      / Double(total)), color: Theme.stripeOrange)
                segment(width: geo.size.width * CGFloat(Double(stats.compressed) / Double(total)), color: Theme.stripePurple)
                segment(width: geo.size.width * CGFloat(Double(stats.inactive)   / Double(total)), color: Theme.stripeBlue)
                segment(width: geo.size.width * CGFloat(Double(stats.free)       / Double(total)), color: Theme.stripeGreen)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .frame(height: 18)
    }

    private func segment(width: CGFloat, color: Color) -> some View {
        Rectangle().fill(color).frame(width: max(0, width))
    }

    private var legend: some View {
        let columns = [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .leading)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            legendRow(name: "Active",     bytes: stats.active,     color: Theme.stripeRed)
            legendRow(name: "Wired",      bytes: stats.wired,      color: Theme.stripeOrange)
            legendRow(name: "Compressed", bytes: stats.compressed, color: Theme.stripePurple)
            legendRow(name: "Inactive",   bytes: stats.inactive,   color: Theme.stripeBlue)
            legendRow(name: "Free",       bytes: stats.free,       color: Theme.stripeGreen)
        }
    }

    private func legendRow(name: String, bytes: Int64, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(name)
                .font(.system(size: 12, weight: .medium))
            Spacer(minLength: 4)
            Text(FileSystemUtils.formatBytes(bytes))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "memorychip")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SidebarItem.memory.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free up memory now")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Runs /usr/sbin/purge with admin auth — frees inactive RAM pages immediately.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await purge() }
                } label: {
                    if isPurging {
                        SweepingBroomLoader(size: 20)
                    } else {
                        Label("Free RAM", systemImage: "wind")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(SidebarItem.memory.tint)
                .disabled(isPurging)
            }
            if let lastResult {
                Text(lastResult)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func purge() async {
        let freeBefore = stats.free
        isPurging = true
        defer { isPurging = false }

        let result = await ShellRunner.run("/usr/sbin/purge", requiresAdmin: true)
        // Wait a beat for kernel to settle, then refresh
        try? await Task.sleep(nanoseconds: 600_000_000)
        stats = MemoryReader.current()
        let freed = max(0, stats.free - freeBefore)

        if result.success {
            lastResult = "Freed \(FileSystemUtils.formatBytes(freed)) of inactive memory."
        } else {
            lastResult = "Failed: \(result.errorMessage ?? "unknown error")"
        }
    }
}
