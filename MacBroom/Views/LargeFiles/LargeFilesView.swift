import SwiftUI
import AppKit

struct LargeFilesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var scanner = LargeFilesScanner()
    @State private var selection = Set<LargeFileItem.ID>()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .largeFiles,
                subtitle: "Big files (>100 MB) in Downloads, Documents, Desktop and Movies"
            )

            HStack(spacing: 12) {
                Button {
                    Task { await scanner.scan() }
                } label: {
                    Label(scanner.isScanning ? "Scanning…" : "Scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(scanner.isScanning)

                if scanner.isScanning { SweepingBroomLoader(size: 24) }

                Spacer()

                if let date = scanner.lastScanDate {
                    Text("Last scan: \(date, style: .relative) ago")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

            Divider()

            if scanner.items.isEmpty && !scanner.isScanning {
                ContentUnavailableView(
                    "Nothing oversized found",
                    systemImage: "checkmark.seal",
                    description: Text("No files larger than 100 MB in your common folders.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(scanner.items) { item in
                        LargeFileRow(item: item, isSelected: selection.contains(item.id)) {
                            toggle(item.id)
                        }
                        .tag(item.id)
                    }
                }
                .listStyle(.inset)
                .alternatingRowBackgrounds()
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

    private func toggle(_ id: LargeFileItem.ID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private var selectedSize: Int64 {
        scanner.items.filter { selection.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(scanner.items.count) files · \(FileSystemUtils.formatBytes(scanner.totalSize)) total")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if !selection.isEmpty {
                    Text("\(selection.count) selected · \(FileSystemUtils.formatBytes(selectedSize))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SidebarItem.largeFiles.tint)
                }
            }
            Spacer()
            Button("Select all") { selection = Set(scanner.items.map(\.id)) }
                .disabled(scanner.items.isEmpty)
            Button("Clear") { selection.removeAll() }
                .disabled(selection.isEmpty)
            Button(role: .destructive) {
                Task {
                    let targets = scanner.items.filter { selection.contains($0.id) }
                    let result = await scanner.clean(targets)
                    selection.removeAll()
                    appState.signalCleanup(reclaimed: result.reclaimed)
                }
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(SidebarItem.largeFiles.tint)
            .disabled(selection.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
    }
}

private struct LargeFileRow: View {
    let item: LargeFileItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? SidebarItem.largeFiles.tint : Color.secondary)
            }
            .buttonStyle(.plain)

            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .interpolation(.medium)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.parentLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(SidebarItem.largeFiles.tint.opacity(0.2)))
                        .foregroundStyle(SidebarItem.largeFiles.tint)
                    Text(item.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let date = item.modifiedAt {
                        Text("· \(date, format: .relative(presentation: .named))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 12)
            Text(FileSystemUtils.formatBytes(item.sizeBytes))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
