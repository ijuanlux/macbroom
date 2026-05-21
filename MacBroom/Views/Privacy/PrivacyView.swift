import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var cleaner = PrivacyCleaner()
    @State private var selection = Set<PrivacyItem.ID>()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .privacy,
                subtitle: "Browser cookies, history, caches across Safari, Chrome, Brave, Firefox, Edge, Arc"
            )

            HStack(spacing: 12) {
                Button {
                    Task { await cleaner.scan() }
                } label: {
                    Label(cleaner.isScanning ? "Scanning…" : "Scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(cleaner.isScanning)

                if cleaner.isScanning { SweepingBroomLoader(size: 24) }
                Spacer()
                if let date = cleaner.lastScanDate {
                    Text("Last scan: \(date, style: .relative) ago")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 10)

            Divider()

            if cleaner.items.isEmpty && !cleaner.isScanning {
                ContentUnavailableView(
                    "All clean",
                    systemImage: "lock.shield",
                    description: Text("No browser cookies, history or cache databases found.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(cleaner.grouped(), id: \.browser) { group in
                            BrowserCard(browser: group.browser,
                                         items: group.items,
                                         total: group.total,
                                         selection: $selection)
                        }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 16)
                }
            }

            Divider()
            footer
        }
        .task {
            if cleaner.lastScanDate == nil { await cleaner.scan() }
        }
    }

    private var footer: some View {
        let selectedItems = cleaner.items.filter { selection.contains($0.id) }
        let selectedSize = selectedItems.reduce(0) { $0 + $1.sizeBytes }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(cleaner.items.count) items · \(FileSystemUtils.formatBytes(cleaner.totalSize)) total")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                if !selection.isEmpty {
                    Text("\(selection.count) selected · \(FileSystemUtils.formatBytes(selectedSize))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SidebarItem.privacy.tint)
                }
            }
            Spacer()
            Button("Select all") { selection = Set(cleaner.items.map(\.id)) }
                .disabled(cleaner.items.isEmpty)
            Button("Clear") { selection.removeAll() }
                .disabled(selection.isEmpty)
            Button(role: .destructive) {
                Task {
                    let targets = cleaner.items.filter { selection.contains($0.id) }
                    let result = await cleaner.clean(targets)
                    selection.removeAll()
                    appState.signalCleanup(reclaimed: result.reclaimed)
                }
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(SidebarItem.privacy.tint)
            .disabled(selection.isEmpty)
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(Theme.cardBackground)
    }
}

private struct BrowserCard: View {
    let browser: PrivacyItem.Browser
    let items: [PrivacyItem]
    let total: Int64
    @Binding var selection: Set<PrivacyItem.ID>

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    PrivacyItemRow(item: item, isSelected: selection.contains(item.id)) {
                        if selection.contains(item.id) { selection.remove(item.id) }
                        else { selection.insert(item.id) }
                    }
                    if item.id != items.last?.id {
                        Divider().opacity(0.25).padding(.leading, 50)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: browser.systemImage)
                .foregroundStyle(SidebarItem.privacy.tint)
            Text(browser.rawValue)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(FileSystemUtils.formatBytes(total))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

private struct PrivacyItemRow: View {
    let item: PrivacyItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? SidebarItem.privacy.tint : Color.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 10)
            Text(FileSystemUtils.formatBytes(item.sizeBytes))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.trailing, 14)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
