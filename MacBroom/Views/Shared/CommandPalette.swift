import SwiftUI

struct PaletteAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let perform: () -> Void

    /// Returns a score in [0..1] for how well this action matches `query`.
    /// 0 = no match, 1 = exact match. Substring matches > 0.
    func score(query: String) -> Double {
        guard !query.isEmpty else { return 0.5 }
        let q = query.lowercased()
        let t = title.lowercased()
        let s = subtitle.lowercased()
        if t == q { return 1.0 }
        if t.hasPrefix(q) { return 0.9 }
        if t.contains(q) { return 0.7 }
        if s.contains(q) { return 0.5 }
        // Loose char-order match (fuzzy)
        return fuzzyScore(q: q, t: t)
    }

    private func fuzzyScore(q: String, t: String) -> Double {
        var ti = t.startIndex
        for qc in q {
            guard let found = t[ti...].firstIndex(of: qc) else { return 0 }
            ti = t.index(after: found)
        }
        return 0.3
    }
}

struct CommandPalette: View {
    @Binding var isPresented: Bool
    let actions: [PaletteAction]

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var focused: Bool

    private var results: [PaletteAction] {
        let scored = actions.map { ($0, $0.score(query: query)) }
        return scored
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    var body: some View {
        ZStack {
            // Background dim — tap to dismiss
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                searchBar
                Divider()
                resultsList
            }
            .frame(width: 540)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LinearGradient.rainbow, lineWidth: 1)
                    .opacity(0.55)
            )
            .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 18)
            .padding(.top, 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            focused = true
            selectedIndex = 0
        }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            TextField("Type a command…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16, design: .rounded))
                .focused($focused)
                .onSubmit { runSelected() }

            Text("ESC")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, action in
                        row(action: action, isSelected: index == selectedIndex)
                            .id(action.id)
                            .onTapGesture {
                                isPresented = false
                                action.perform()
                            }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 380)
            .onChange(of: selectedIndex) { _, newValue in
                if newValue < results.count {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(results[newValue].id, anchor: .center)
                    }
                }
            }
        }
        .background(KeyHandler(
            onUp: { selectedIndex = max(0, selectedIndex - 1) },
            onDown: { selectedIndex = min(results.count - 1, selectedIndex + 1) },
            onEnter: { runSelected() },
            onEscape: { isPresented = false }
        ))
    }

    private func row(action: PaletteAction, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(action.tint.opacity(0.20))
                    .frame(width: 28, height: 28)
                Image(systemName: action.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(action.tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(action.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(action.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? action.tint.opacity(0.15) : Color.clear)
        )
    }

    private func runSelected() {
        guard !results.isEmpty, selectedIndex < results.count else { return }
        let action = results[selectedIndex]
        isPresented = false
        action.perform()
    }
}

/// Hidden NSView that captures arrow keys + return + escape for the palette.
private struct KeyHandler: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlingView()
        view.onUp = onUp
        view.onDown = onDown
        view.onEnter = onEnter
        view.onEscape = onEscape
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class KeyHandlingView: NSView {
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: onUp?()      // up arrow
        case 125: onDown?()    // down arrow
        case 36, 76: onEnter?() // return, numpad enter
        case 53:  onEscape?()  // escape
        default:  super.keyDown(with: event)
        }
    }
}
