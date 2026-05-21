import SwiftUI

struct DevJunkView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var scanner = DevJunkScanner()
    @State private var selection = Set<ScanItem.ID>()
    @State private var collapsed = Set<ScanItem.DevCategory>()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .devJunk,
                subtitle: "Build artifacts, package caches and Docker data"
            )

            toolbar
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            Divider()

            if scanner.items.isEmpty && !scanner.isScanning {
                emptyState
            } else {
                groupedList
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

    private var groupedList: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: []) {
                ForEach(scanner.grouped(), id: \.category) { group in
                    DevCategoryCard(
                        category: group.category,
                        items: group.items,
                        total: group.total,
                        isCollapsed: collapsed.contains(group.category),
                        selection: $selection,
                        onToggleCollapse: { toggleCollapse(group.category) },
                        onToggleAll: { toggleAll(in: group.items) }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing to clean",
            systemImage: "sparkles",
            description: Text("None of the known dev caches and build artifacts are present on this Mac.")
        )
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(scanner.items.count) items · \(FileSystemUtils.formatBytes(scanner.totalSize)) total")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if !selection.isEmpty {
                    Text("\(selection.count) selected · \(FileSystemUtils.formatBytes(selectedSize))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SidebarItem.devJunk.tint)
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
            .tint(SidebarItem.devJunk.tint)
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

    private func toggleCollapse(_ category: ScanItem.DevCategory) {
        if collapsed.contains(category) {
            collapsed.remove(category)
        } else {
            collapsed.insert(category)
        }
    }

    private func toggleAll(in items: [ScanItem]) {
        let ids = items.map(\.id)
        let allSelected = ids.allSatisfy { selection.contains($0) }
        if allSelected {
            ids.forEach { selection.remove($0) }
        } else {
            ids.forEach { selection.insert($0) }
        }
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

// MARK: - Category Card

private struct DevCategoryCard: View {
    let category: ScanItem.DevCategory
    let items: [ScanItem]
    let total: Int64
    let isCollapsed: Bool
    @Binding var selection: Set<ScanItem.ID>
    let onToggleCollapse: () -> Void
    let onToggleAll: () -> Void

    private var selectedCount: Int {
        items.filter { selection.contains($0.id) }.count
    }

    private var allSelected: Bool {
        !items.isEmpty && selectedCount == items.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !isCollapsed {
                Divider().opacity(0.5)
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        DevItemRow(item: item, isSelected: selection.contains(item.id)) {
                            toggle(item.id)
                        }
                        if item.id != items.last?.id {
                            Divider().opacity(0.3).padding(.leading, 56)
                        }
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
        HStack(spacing: 12) {
            Button(action: onToggleAll) {
                Image(systemName: allSelected ? "checkmark.square.fill" : (selectedCount > 0 ? "minus.square.fill" : "square"))
                    .font(.system(size: 17))
                    .foregroundStyle(allSelected || selectedCount > 0 ? SidebarItem.devJunk.tint : Color.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: category.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SidebarItem.devJunk.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(FileSystemUtils.formatBytes(total))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))

            Button(action: onToggleCollapse) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggleCollapse)
    }

    private func toggle(_ id: ScanItem.ID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
}

private struct DevItemRow: View {
    let item: ScanItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? SidebarItem.devJunk.tint : Color.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(item.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Text(FileSystemUtils.formatBytes(item.sizeBytes))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.trailing, 14)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
