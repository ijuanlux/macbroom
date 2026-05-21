import SwiftUI
import AppKit

struct DuplicatesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var finder = DuplicateFinder()
    @State private var selection = Set<UUID>()  // selects DuplicateFile.id

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .duplicates,
                subtitle: "Same content, different copies. Keep one, trash the rest."
            )

            HStack(spacing: 12) {
                Button {
                    Task { await finder.scan() }
                } label: {
                    Label(finder.isScanning ? "Scanning…" : "Scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(finder.isScanning)

                if finder.isScanning {
                    HStack(spacing: 8) {
                        SweepingBroomLoader(size: 22)
                        Text(finder.progressNote)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let date = finder.lastScanDate {
                    Text("Last scan: \(date, style: .relative) ago")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

            Divider()

            if finder.groups.isEmpty && !finder.isScanning {
                ContentUnavailableView(
                    "No duplicates",
                    systemImage: "checkmark.seal",
                    description: Text("No duplicate files found in Downloads, Documents and Desktop.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(finder.groups) { group in
                            DuplicateGroupCard(group: group, selection: $selection)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }

            Divider()
            footer
        }
        .task {
            if finder.lastScanDate == nil { await finder.scan() }
        }
    }

    private var selectedFiles: [DuplicateFile] {
        let ids = selection
        return finder.groups.flatMap { $0.files }.filter { ids.contains($0.id) }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(finder.groups.count) duplicate groups · \(FileSystemUtils.formatBytes(finder.totalWaste)) recoverable")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if !selection.isEmpty {
                    let total = selectedFiles.reduce(0) { $0 + $1.sizeBytes }
                    Text("\(selection.count) selected · \(FileSystemUtils.formatBytes(total))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SidebarItem.duplicates.tint)
                }
            }
            Spacer()
            Button("Keep newest, trash rest") { autoSelectAllButFirst() }
                .disabled(finder.groups.isEmpty)
            Button("Clear") { selection.removeAll() }
                .disabled(selection.isEmpty)
            Button(role: .destructive) {
                Task {
                    let urls = selectedFiles.map(\.url)
                    let result = await finder.clean(urls)
                    selection.removeAll()
                    appState.signalCleanup(reclaimed: result.reclaimed)
                }
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(SidebarItem.duplicates.tint)
            .disabled(selection.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
    }

    /// Auto-select: in each group, keep the first file, mark the rest for deletion.
    private func autoSelectAllButFirst() {
        var newSelection = Set<UUID>()
        for group in finder.groups {
            for (idx, file) in group.files.enumerated() where idx > 0 {
                newSelection.insert(file.id)
            }
        }
        selection = newSelection
    }
}

private struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    @Binding var selection: Set<UUID>

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            VStack(spacing: 0) {
                ForEach(Array(group.files.enumerated()), id: \.element.id) { idx, file in
                    DuplicateFileRow(
                        file: file,
                        isFirst: idx == 0,
                        isSelected: selection.contains(file.id)
                    ) {
                        toggle(file.id)
                    }
                    if file.id != group.files.last?.id {
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
            Image(systemName: "square.on.square")
                .foregroundStyle(SidebarItem.duplicates.tint)
            Text("\(group.files.count) copies · \(FileSystemUtils.formatBytes(group.sizeBytes)) each")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("Wasting \(FileSystemUtils.formatBytes(group.wastedBytes))")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(SidebarItem.duplicates.tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func toggle(_ id: UUID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }
}

private struct DuplicateFileRow: View {
    let file: DuplicateFile
    let isFirst: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? SidebarItem.duplicates.tint : Color.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 14)

            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable()
                .interpolation(.medium)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(file.url.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if isFirst {
                        Text("KEEP")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.stripeGreen.opacity(0.25)))
                            .foregroundStyle(Theme.stripeGreen)
                    }
                }
                Text(file.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 10)
            Text(FileSystemUtils.formatBytes(file.sizeBytes))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.trailing, 14)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
