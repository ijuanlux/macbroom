import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var scanner = StorageScanner()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .dashboard,
                subtitle: "Storage overview and quick actions"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SmartScanCard()
                    StatsCard()
                    storageCard
                    quickWinsSection
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
    }

    // MARK: - Storage card

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Macintosh HD")
                        .font(.system(size: 18, weight: .semibold))
                    if scanner.totalBytes > 0 {
                        Text("\(FileSystemUtils.formatBytes(scanner.usedBytes)) used · \(FileSystemUtils.formatBytes(scanner.availableBytes)) available · \(FileSystemUtils.formatBytes(scanner.totalBytes)) total")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    Task { await scanner.scan() }
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(scanner.isScanning)
            }

            stackedBar

            if scanner.isScanning && scanner.usages.isEmpty {
                HStack(spacing: 10) {
                    SweepingBroomLoader(size: 20)
                    Text("Measuring categories…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            legend
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var stackedBar: some View {
        GeometryReader { geo in
            let total = scanner.totalBytes
            let segments = scanner.usages.filter { $0.sizeBytes > 0 }
            HStack(spacing: 1) {
                ForEach(segments) { usage in
                    let width = total > 0
                        ? geo.size.width * CGFloat(Double(usage.sizeBytes) / Double(total))
                        : 0
                    Rectangle()
                        .fill(usage.category.color)
                        .frame(width: max(0, width))
                        .help("\(usage.category.rawValue) · \(FileSystemUtils.formatBytes(usage.sizeBytes))")
                }
                // Free space block
                if scanner.availableBytes > 0, total > 0 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .help("Available · \(FileSystemUtils.formatBytes(scanner.availableBytes))")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .frame(height: 24)
    }

    private var legend: some View {
        let columns = [GridItem(.adaptive(minimum: 200), spacing: 12, alignment: .leading)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(scanner.usages) { usage in
                HStack(spacing: 8) {
                    Circle()
                        .fill(usage.category.color)
                        .frame(width: 9, height: 9)
                    Text(usage.category.rawValue)
                        .font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 4)
                    Text(FileSystemUtils.formatBytes(usage.sizeBytes))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    .frame(width: 9, height: 9)
                Text("Available")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(FileSystemUtils.formatBytes(scanner.availableBytes))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Quick wins

    private var quickWinsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick wins")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            let columns = [GridItem(.adaptive(minimum: 240), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                QuickWinCard(
                    item: .caches,
                    headline: "Clear app caches",
                    blurb: "Free space taken by application caches and user logs."
                ) { appState.selection = .caches }

                QuickWinCard(
                    item: .devJunk,
                    headline: "Clear developer junk",
                    blurb: "Reclaim space from build artifacts and package caches."
                ) { appState.selection = .devJunk }

                QuickWinCard(
                    item: .uninstaller,
                    headline: "Uninstall apps",
                    blurb: "Remove apps and the leftover files they leave behind."
                ) { appState.selection = .uninstaller }
            }
        }
    }
}

private struct QuickWinCard: View {
    let item: SidebarItem
    let headline: String
    let blurb: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(item.tint.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: item.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(item.tint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(headline)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(blurb)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2, reservesSpace: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
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
        .buttonStyle(.plain)
    }
}
