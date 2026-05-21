import SwiftUI

struct SmartScanCard: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("macbroom.hackerMode") private var hackerMode: Bool = false
    @StateObject private var coordinator = SmartScanCoordinator()

    private var stripes: [Color] {
        hackerMode ? Theme.hackerStripes : Theme.rainbow
    }
    private var stripesGradient: LinearGradient {
        hackerMode ? LinearGradient.hackerStripes : LinearGradient.rainbow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            content
        }
        .padding(22)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(stripesGradient, lineWidth: 1)
                .opacity(0.55)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(
                        colors: stripes,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Scan")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("One-click sweep of caches and developer junk")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var content: some View {
        switch coordinator.phase {
        case .idle:           idleContent
        case .scanning:       scanningContent
        case .ready(let bytes, let count): readyContent(bytes: bytes, count: count)
        case .cleaning:       cleaningContent
        case .done(let bytes): doneContent(reclaimed: bytes)
        }
    }

    private var idleContent: some View {
        HStack {
            Text("Press to scan caches and developer artifacts in parallel.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            RainbowButton("Smart Scan", systemImage: "sparkles") {
                Task { await coordinator.scan() }
            }
        }
    }

    private var scanningContent: some View {
        HStack(spacing: 14) {
            SweepingBroomLoader(size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sweeping your Mac…")
                    .font(.system(size: 14, weight: .semibold))
                Text("Scanning caches, logs, dev artifacts, package caches")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func readyContent(bytes: Int64, count: Int) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(FileSystemUtils.formatBytes(bytes))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(stripesGradient)
                Text("\(count) items ready to clean")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 8) {
                RainbowButton("Clean all", systemImage: "trash") {
                    Task {
                        let reclaimed = await coordinator.cleanAll()
                        appState.signalCleanup(reclaimed: reclaimed)
                    }
                }
                Button("Scan again") {
                    Task { await coordinator.scan() }
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var cleaningContent: some View {
        HStack(spacing: 14) {
            SweepingBroomLoader(size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cleaning…")
                    .font(.system(size: 14, weight: .semibold))
                Text("Moving items to Trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func doneContent(reclaimed: Int64) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.stripeGreen)
                    Text(reclaimed > 0 ? "All clean" : "Already clean")
                        .font(.system(size: 16, weight: .semibold))
                }
                if reclaimed > 0 {
                    Text("Reclaimed \(FileSystemUtils.formatBytes(reclaimed))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No reclaimable junk found right now")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Run again") {
                Task { await coordinator.scan() }
            }
            .controlSize(.regular)
        }
    }

    // MARK: - Background

    private var cardBackground: some View {
        ZStack {
            Theme.cardBackground
            LinearGradient(colors: stripes,
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .opacity(0.08)
        }
    }
}

