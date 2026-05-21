import SwiftUI
import AppKit

struct StartupItemsView: View {
    @StateObject private var scanner = StartupItemsScanner()
    @State private var query: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .startup,
                subtitle: "What macOS launches automatically — LaunchAgents and Daemons."
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

                TextField("Search startup items", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
            .padding(.horizontal, 24).padding(.bottom, 10)

            Divider()

            if scanner.items.isEmpty && !scanner.isScanning {
                ContentUnavailableView(
                    "No startup items",
                    systemImage: "power.dotted",
                    description: Text("Nothing in ~/Library/LaunchAgents, /Library/LaunchAgents or /Library/LaunchDaemons.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(scanner.grouped(), id: \.scope) { group in
                            ScopeCard(
                                scope: group.scope,
                                items: filtered(group.items),
                                onToggle: { item in
                                    Task { _ = await scanner.toggleDisabled(item) }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 16)
                }
            }

            Divider()
            footer
        }
        .task {
            if scanner.lastScanDate == nil { await scanner.scan() }
        }
    }

    private func filtered(_ items: [StartupItem]) -> [StartupItem] {
        guard !query.isEmpty else { return items }
        let q = query.lowercased()
        return items.filter {
            $0.label.lowercased().contains(q) ||
            ($0.program?.lowercased().contains(q) ?? false)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(scanner.items.count) startup items found")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            if let date = scanner.lastScanDate {
                Text("Last scan: \(date, style: .relative) ago")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(Theme.cardBackground)
    }
}

private struct ScopeCard: View {
    let scope: StartupItem.Scope
    let items: [StartupItem]
    let onToggle: (StartupItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    StartupRow(item: item, onToggle: { onToggle(item) })
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
            Image(systemName: "folder.fill")
                .foregroundStyle(SidebarItem.startup.tint)
            Text(scope.displayName)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

private struct StartupRow: View {
    let item: StartupItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDisabledInPlist ? "pause.circle" : "play.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(item.isDisabledInPlist ? Color.secondary : Theme.stripeGreen)
                .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.label)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if item.requiresAdmin {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help("System-level — cannot toggle from MacBroom")
                    }
                }
                if let program = item.program {
                    Text(program.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 10)
            Button(action: onToggle) {
                Text(item.isDisabledInPlist ? "Enable" : "Disable")
                    .font(.system(size: 11, weight: .semibold))
            }
            .controlSize(.small)
            .disabled(item.requiresAdmin)
            .padding(.trailing, 14)
        }
        .padding(.vertical, 7)
    }
}
