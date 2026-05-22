import SwiftUI
import AppKit

struct DiskExplorerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var scanner = TreemapScanner()
    @State private var hovered: TreemapNode.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .explorer,
                subtitle: "Treemap of folder contents. Click to drill in. Style: DaisyDisk."
            )

            toolbar
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            Divider()

            ZStack {
                if scanner.isScanning {
                    SweepingBroomLoader(size: 48)
                } else if scanner.children.isEmpty {
                    ContentUnavailableView(
                        "Empty folder",
                        systemImage: "folder",
                        description: Text("Nothing measurable inside this folder.")
                    )
                } else {
                    GeometryReader { geo in
                        TreemapCanvas(
                            children: scanner.children,
                            total: scanner.totalSize,
                            size: geo.size,
                            hovered: $hovered,
                            onDrillIn: { node in
                                Task { await scanner.navigate(to: node.url) }
                            }
                        )
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            footer
        }
        .task {
            if scanner.children.isEmpty { await scanner.scan() }
        }
        .onChange(of: appState.requestedExplorerURL) { _, url in
            guard let url else { return }
            appState.requestedExplorerURL = nil
            Task { await scanner.navigate(to: url) }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                Task { await scanner.goUp() }
            } label: {
                Label("Up", systemImage: "arrow.up")
            }
            .disabled(scanner.path.path == "/" && scanner.history.isEmpty)

            Button {
                Task { await scanner.scan() }
            } label: {
                Label(scanner.isScanning ? "Scanning…" : "Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(scanner.isScanning)

            Button {
                pickFolder()
            } label: {
                Label("Pick folder", systemImage: "folder.badge.questionmark")
            }

            Spacer()

            Text(scanner.path.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if scanner.isScanning {
                SweepingBroomLoader(size: 22)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(scanner.children.count) items · \(FileSystemUtils.formatBytes(scanner.totalSize)) total")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            if let hovered, let node = scanner.children.first(where: { $0.id == hovered }) {
                HStack(spacing: 6) {
                    Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                        .foregroundStyle(SidebarItem.explorer.tint)
                    Text(node.displayName)
                        .font(.system(size: 12, weight: .medium))
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(FileSystemUtils.formatBytes(node.sizeBytes))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to explore"
        panel.prompt = "Explore"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await scanner.navigate(to: url) }
        }
    }
}

// MARK: - Treemap layout

private struct TreemapCanvas: View {
    let children: [TreemapNode]
    let total: Int64
    let size: CGSize
    @Binding var hovered: TreemapNode.ID?
    let onDrillIn: (TreemapNode) -> Void

    var body: some View {
        let layout = sliceAndDice(children: children, in: CGRect(origin: .zero, size: size))
        ZStack(alignment: .topLeading) {
            ForEach(layout, id: \.node.id) { tile in
                TreemapTile(
                    node: tile.node,
                    rect: tile.rect,
                    isHovered: hovered == tile.node.id,
                    onHover: { isHovering in
                        hovered = isHovering ? tile.node.id : (hovered == tile.node.id ? nil : hovered)
                    },
                    onTap: {
                        if tile.node.isDirectory { onDrillIn(tile.node) }
                    }
                )
            }
        }
    }

    private func sliceAndDice(children: [TreemapNode], in rect: CGRect) -> [(node: TreemapNode, rect: CGRect)] {
        guard total > 0, !children.isEmpty else { return [] }
        var results: [(TreemapNode, CGRect)] = []
        var remaining = rect
        let horizontal = rect.width > rect.height
        let totalDouble = Double(total)

        for (index, node) in children.enumerated() {
            let isLast = index == children.count - 1
            if isLast {
                results.append((node, remaining))
                break
            }
            let ratio = Double(node.sizeBytes) / totalDouble
            if horizontal {
                let width = remaining.width * CGFloat(ratio)
                let r = CGRect(x: remaining.minX, y: remaining.minY,
                               width: width, height: remaining.height)
                results.append((node, r))
                remaining.origin.x += width
                remaining.size.width -= width
            } else {
                let height = remaining.height * CGFloat(ratio)
                let r = CGRect(x: remaining.minX, y: remaining.minY,
                               width: remaining.width, height: height)
                results.append((node, r))
                remaining.origin.y += height
                remaining.size.height -= height
            }
        }
        return results
    }
}

private struct TreemapTile: View {
    let node: TreemapNode
    let rect: CGRect
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void

    private var tileColor: Color {
        // Deterministic color per node based on first character of name.
        let palette: [Color] = Theme.rainbow + [SidebarItem.explorer.tint, SidebarItem.memory.tint]
        let scalar = node.displayName.unicodeScalars.first?.value ?? 0
        return palette[Int(scalar) % palette.count]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(tileColor.opacity(node.isDirectory ? 0.55 : 0.35))
            Rectangle()
                .strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
            if rect.width > 70, rect.height > 30 {
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.displayName)
                        .font(.system(size: rect.width > 140 ? 12 : 10, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(FileSystemUtils.formatBytes(node.sizeBytes))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.85))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 4)
            }
            if isHovered {
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 2)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
        .onHover(perform: onHover)
        .onTapGesture(perform: onTap)
        .help("\(node.displayName) · \(FileSystemUtils.formatBytes(node.sizeBytes))")
    }
}
