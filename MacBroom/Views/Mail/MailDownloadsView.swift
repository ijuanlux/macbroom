import SwiftUI
import AppKit

struct MailDownloadsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var scanner = MailDownloadsScanner()
    @State private var selection = Set<MailDownloadItem.ID>()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .mail,
                subtitle: "Mail attachments and downloaded files older than 30 days"
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
            .padding(.horizontal, 24).padding(.bottom, 10)

            Divider()

            if scanner.items.isEmpty && !scanner.isScanning {
                ContentUnavailableView(
                    "Nothing stale",
                    systemImage: "envelope.open",
                    description: Text("No mail attachments stored locally and no old files in Downloads.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    Section("Mail attachments") {
                        ForEach(mailAttachments) { item in
                            row(item: item)
                                .tag(item.id)
                        }
                    }
                    Section("Old in Downloads (>30 days)") {
                        ForEach(oldDownloads) { item in
                            row(item: item)
                                .tag(item.id)
                        }
                    }
                }
                .listStyle(.inset)
                .alternatingRowBackgrounds()
            }

            Divider()
            footer
        }
        .task {
            if scanner.lastScanDate == nil { await scanner.scan() }
        }
    }

    private var mailAttachments: [MailDownloadItem] {
        scanner.items.filter { $0.source == .mailAttachment }
    }

    private var oldDownloads: [MailDownloadItem] {
        scanner.items.filter { $0.source == .oldDownload }
    }

    private func row(item: MailDownloadItem) -> some View {
        HStack(spacing: 12) {
            Button {
                if selection.contains(item.id) { selection.remove(item.id) }
                else { selection.insert(item.id) }
            } label: {
                Image(systemName: selection.contains(item.id) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundStyle(selection.contains(item.id) ? SidebarItem.mail.tint : Color.secondary)
            }
            .buttonStyle(.plain)
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable().interpolation(.medium)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if let date = item.modifiedAt {
                    Text("Modified \(date, format: .relative(presentation: .named))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            Text(FileSystemUtils.formatBytes(item.sizeBytes))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private var footer: some View {
        let selectedItems = scanner.items.filter { selection.contains($0.id) }
        let selectedSize = selectedItems.reduce(0) { $0 + $1.sizeBytes }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(scanner.items.count) items · \(FileSystemUtils.formatBytes(scanner.totalSize)) total")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                if !selection.isEmpty {
                    Text("\(selection.count) selected · \(FileSystemUtils.formatBytes(selectedSize))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SidebarItem.mail.tint)
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
            .tint(SidebarItem.mail.tint)
            .disabled(selection.isEmpty)
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(Theme.cardBackground)
    }
}
