import SwiftUI
import AppKit

struct MenuBarContent: View {
    @State private var totalBytes: Int64 = 0
    @State private var availableBytes: Int64 = 0
    @State private var memStats: MemoryStats = .zero
    @State private var isPurging: Bool = false

    private let refresh = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            diskRow
            memoryRow
            Divider()
            actions
        }
        .padding(14)
        .frame(width: 280)
        .onAppear { refreshAll() }
        .onReceive(refresh) { _ in refreshAll() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            AppIconView(size: 24)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text("MacBroom")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer()
        }
    }

    private var diskRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Disk", systemImage: "internaldrive")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(FileSystemUtils.formatBytes(availableBytes)) free")
                    .font(.system(size: 11, design: .monospaced))
            }
            ProgressView(value: Double(totalBytes - availableBytes), total: Double(max(1, totalBytes)))
                .controlSize(.mini)
                .tint(Theme.stripeBlue)
        }
    }

    private var memoryRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("RAM", systemImage: "memorychip")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(FileSystemUtils.formatBytes(memStats.free)) free")
                    .font(.system(size: 11, design: .monospaced))
            }
            ProgressView(value: Double(memStats.used), total: Double(max(1, memStats.total)))
                .controlSize(.mini)
                .tint(Theme.stripeOrange)
        }
    }

    private var actions: some View {
        VStack(spacing: 6) {
            Button {
                openMainWindow()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Open MacBroom")
                    Spacer()
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: Theme.rainbow, startPoint: .leading, endPoint: .trailing)
                        .opacity(0.85)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .foregroundStyle(.white)
                .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)

            Button {
                Task { await purgeRAM() }
            } label: {
                HStack {
                    if isPurging { SweepingBroomLoader(size: 14) } else { Image(systemName: "wind") }
                    Text(isPurging ? "Freeing memory…" : "Free RAM (purge)")
                    Spacer()
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(SidebarItem.memory.tint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .foregroundStyle(SidebarItem.memory.tint)
                .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(isPurging)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                    Spacer()
                    Text("⌘Q").foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
    }

    // MARK: - Helpers

    private func refreshAll() {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]) {
            totalBytes = Int64(values.volumeTotalCapacity ?? 0)
            availableBytes = values.volumeAvailableCapacityForImportantUsage
                ?? Int64(values.volumeAvailableCapacity ?? 0)
        }
        memStats = MemoryReader.current()
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Find or recreate the main window
        for window in NSApp.windows where window.title.contains("MacBroom") || window.contentViewController != nil {
            window.makeKeyAndOrderFront(nil)
            return
        }
        // Fallback: send a "new window" command
        NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
    }

    private func purgeRAM() async {
        isPurging = true
        defer { isPurging = false }
        _ = await ShellRunner.run("/usr/sbin/purge", requiresAdmin: true)
        try? await Task.sleep(nanoseconds: 600_000_000)
        memStats = MemoryReader.current()
    }
}
