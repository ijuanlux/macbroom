import SwiftUI
import AppKit

struct CachesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var scanner = CacheScanner()
    @State private var selection = Set<ScanItem.ID>()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .caches,
                subtitle: "Application caches and user logs in your home folder"
            )

            toolbar
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            Divider()

            if scanner.items.isEmpty && !scanner.isScanning {
                emptyState
            } else {
                itemList
            }

            Divider()
            footer
        }
        .task {
            if scanner.lastScanDate == nil {
                await scanner.scan()
            }
        }
    }

    // MARK: - Top toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await scanner.scan() }
            } label: {
                Label(scanner.isScanning ? "Scanning…" : "Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(scanner.isScanning)

            if scanner.isScanning {
                SweepingBroomLoader(size: 24)
            }

            Spacer()

            if let date = scanner.lastScanDate {
                Text("Last scan: \(date, style: .relative) ago")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - List

    private var itemList: some View {
        List(selection: $selection) {
            ForEach(scanner.items) { item in
                CacheRow(item: item, isSelected: selection.contains(item.id)) {
                    toggle(item.id)
                }
                .tag(item.id)
            }
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds()
    }

    private func toggle(_ id: ScanItem.ID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        ContentUnavailableView(
            "All clean",
            systemImage: "sparkles",
            description: Text("No cache items found. Run a scan to check again.")
        )
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(scanner.items.count) items · \(FileSystemUtils.formatBytes(scanner.totalSize)) total")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if !selection.isEmpty {
                    Text("\(selection.count) selected · \(FileSystemUtils.formatBytes(selectedSize))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SidebarItem.caches.tint)
                }
            }

            Spacer()

            Button("Select all") { selectAll() }
                .disabled(scanner.items.isEmpty)

            Button("Clear") { selection.removeAll() }
                .disabled(selection.isEmpty)

            Button(role: .destructive) {
                Task { await cleanSelected() }
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(SidebarItem.caches.tint)
            .disabled(selection.isEmpty || scanner.isScanning)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
    }

    private var selectedSize: Int64 {
        scanner.items
            .filter { selection.contains($0.id) }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    private func selectAll() {
        selection = Set(scanner.items.map(\.id))
    }

    private func cleanSelected() async {
        let targets = scanner.items.filter { selection.contains($0.id) }
        let result = await scanner.clean(targets)
        selection.removeAll()
        appState.signalCleanup(reclaimed: result.reclaimed)
    }
}

// MARK: - Row

private struct CacheRow: View {
    let item: ScanItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? SidebarItem.caches.tint : Color.secondary)
            }
            .buttonStyle(.plain)

            iconImage
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 16)

            Text(FileSystemUtils.formatBytes(item.sizeBytes))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

    @ViewBuilder
    private var iconImage: some View {
        if case let .appCache(bundleId?) = item.kind,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .interpolation(.medium)
        } else {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
        }
    }
}
