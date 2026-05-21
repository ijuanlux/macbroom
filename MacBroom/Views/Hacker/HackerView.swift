import SwiftUI

struct HackerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var feed = HackerFeed()
    @State private var cursorOn = true

    private let hackerGreen = Color(red: 0.20, green: 0.95, blue: 0.35)
    private let dimGreen    = Color(red: 0.10, green: 0.55, blue: 0.20)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MatrixRain()
                .opacity(0.45)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    asciiTitle
                    statusLine
                    terminalCard
                    actions
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            await feed.start()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                cursorOn.toggle()
            }
        }
    }

    // MARK: - Header

    private var asciiTitle: some View {
        Text(asciiArt)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(hackerGreen)
            .shadow(color: hackerGreen.opacity(0.6), radius: 6)
            .lineSpacing(1)
            .accessibilityHidden(true)
    }

    private let asciiArt = """
███╗   ███╗ █████╗  ██████╗██████╗ ██████╗  ██████╗  ██████╗ ███╗   ███╗
████╗ ████║██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔═══██╗██╔═══██╗████╗ ████║
██╔████╔██║███████║██║     ██████╔╝██████╔╝██║   ██║██║   ██║██╔████╔██║
██║╚██╔╝██║██╔══██║██║     ██╔══██╗██╔══██╗██║   ██║██║   ██║██║╚██╔╝██║
██║ ╚═╝ ██║██║  ██║╚██████╗██████╔╝██║  ██║╚██████╔╝╚██████╔╝██║ ╚═╝ ██║
╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝     ╚═╝
"""

    private var statusLine: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Circle()
                    .fill(hackerGreen)
                    .frame(width: 7, height: 7)
                    .shadow(color: hackerGreen.opacity(0.9), radius: 4)
                Text("CONNECTED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(hackerGreen)
            }
            Text("·")
                .foregroundStyle(dimGreen)
            Text("session: \(UUID().uuidString.prefix(8))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(dimGreen)
            Spacer()
            Text(feed.isRunning ? "running…" : "idle")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(dimGreen)
        }
    }

    // MARK: - Terminal

    private var terminalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            terminalTitleBar
            terminalBody
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(hackerGreen.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: hackerGreen.opacity(0.35), radius: 18)
    }

    private var terminalTitleBar: some View {
        HStack(spacing: 6) {
            Circle().fill(Color(red: 1.0, green: 0.36, blue: 0.36)).frame(width: 9, height: 9)
            Circle().fill(Color(red: 1.0, green: 0.78, blue: 0.20)).frame(width: 9, height: 9)
            Circle().fill(hackerGreen).frame(width: 9, height: 9)
            Spacer()
            Text("macbroom@local — zsh — 120x40")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(dimGreen)
            Spacer()
            Color.clear.frame(width: 33)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .overlay(Divider().opacity(0.4), alignment: .bottom)
    }

    private var terminalBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(feed.lines.indices, id: \.self) { i in
                let line = feed.lines[i]
                Text(line.isEmpty ? " " : line)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(colorFor(line))
            }
            if feed.isRunning {
                Text("▌")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(cursorOn ? hackerGreen : Color.clear)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func colorFor(_ line: String) -> Color {
        if line.hasPrefix("$ ")     { return hackerGreen }
        if line.hasPrefix("◆ ")     { return Color(red: 0.4, green: 1.0, blue: 0.6) }
        if line.hasPrefix("[")      { return Color(red: 1.0, green: 0.85, blue: 0.30) }
        if line.hasPrefix(">")      { return dimGreen }
        return hackerGreen.opacity(0.85)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 12) {
            terminalButton(title: "$ rerun-scan", systemImage: "arrow.clockwise") {
                Task { await feed.start() }
            }
            terminalButton(title: "$ smart-clean", systemImage: "sparkles") {
                appState.selection = .dashboard
            }
            Spacer()
        }
    }

    private func terminalButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(hackerGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(hackerGreen.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
