import SwiftUI

// MARK: - Phase

enum CharacterPhase: Equatable {
    case idle
    case scanning
    case ready(bytes: Int64)
    case cleaning
    case done(reclaimed: Int64)

    var isWorking: Bool {
        switch self {
        case .scanning, .cleaning: return true
        default: return false
        }
    }
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

// MARK: - Pixel-art glasses

struct ThugLifeGlasses: View {
    private let pattern: [[Int]] = [
        [0,1,1,1,1,1,0,0,0,1,1,1,1,1,0,0],
        [1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,0],
        [0,1,1,1,1,1,0,0,0,1,1,1,1,1,0,0],
    ]
    var body: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / 16
            let cellH = geo.size.height / 6
            ZStack(alignment: .topLeading) {
                ForEach(0..<pattern.count, id: \.self) { row in
                    ForEach(0..<pattern[row].count, id: \.self) { col in
                        if pattern[row][col] == 1 {
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: cellW + 0.5, height: cellH + 0.5)
                                .offset(x: CGFloat(col) * cellW, y: CGFloat(row) * cellH)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Mood / dialogue

@MainActor
final class CharacterMood: ObservableObject {
    @Published var message: String?

    private var spontaneousTimer: Timer?
    private var currentPhase: CharacterPhase = .idle

    private let idleMessages: [String] = [
        "uff this mac is full of trash",
        "smart scan me bro",
        "your downloads folder is wild",
        "imagine 50 GB of node_modules",
        "ready when you are 😎",
        "tap me for the magic",
        "i was built different",
        "system caches are SUS",
        "404 free space, almost…",
        "bored. clean me.",
        "wanna sweep something?",
    ]
    private let scanningMessages: [String] = [
        "sniffing your library…",
        "checking dev junk…",
        "hmm this is a lot…",
        "uno momento…",
    ]
    private let readyMessages: [String] = [
        "look at all this junk",
        "uff tap to clean",
        "i found GOLD bro",
        "permission to sweep?",
        "ready, willing, broom-able",
    ]
    private let cleaningMessages: [String] = [
        "sweep sweep sweep",
        "delete delete delete",
        "byebye trash",
        "almost done…",
    ]
    private let doneMessages: [String] = [
        "we did it 🧹",
        "feels lighter already",
        "smooth like butter",
        "next round?",
    ]

    func update(phase: CharacterPhase) {
        let wasReady = currentPhase.isReady
        currentPhase = phase
        switch phase {
        case .scanning: speak(scanningMessages.randomElement() ?? "scanning…")
        case .cleaning: speak(cleaningMessages.randomElement() ?? "sweeping…")
        case .done(let b) where b > 0:
            speak(doneMessages.randomElement() ?? "done")
        case .ready where !wasReady:
            speak(readyMessages.randomElement() ?? "tap to clean")
        default: break
        }
    }

    func start() {
        stop()
        spontaneousTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 12...22), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fireSpontaneous() }
        }
    }
    func stop() {
        spontaneousTimer?.invalidate()
        spontaneousTimer = nil
    }

    private func fireSpontaneous() {
        guard !currentPhase.isWorking else { return }
        let pool: [String]
        switch currentPhase {
        case .idle:     pool = idleMessages
        case .ready:    pool = readyMessages
        case .done:     pool = doneMessages
        case .scanning: pool = scanningMessages
        case .cleaning: pool = cleaningMessages
        }
        speak(pool.randomElement() ?? "hey")
    }

    private func speak(_ text: String, duration: Double = 3.5) {
        withAnimation(.easeOut(duration: 0.25)) { message = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            withAnimation(.easeIn(duration: 0.3)) { self?.message = nil }
        }
    }
}

// MARK: - Trash item

private struct TrashItem: Identifiable, Hashable {
    let id = UUID()
    let symbol: String      // SF symbol name
    let color: Color
    let baseX: CGFloat      // horizontal position (0..1 relative to scene width)
    let size: CGFloat       // px
    let rotation: Double    // degrees
}

private extension TrashItem {
    static func defaults() -> [TrashItem] {
        [
            TrashItem(symbol: "shippingbox.fill", color: Theme.stripeOrange, baseX: 0.10, size: 28, rotation: -8),
            TrashItem(symbol: "doc.fill",          color: Theme.stripeBlue,   baseX: 0.22, size: 22, rotation: 12),
            TrashItem(symbol: "trash.fill",        color: Theme.stripeRed,    baseX: 0.32, size: 26, rotation: -3),
            TrashItem(symbol: "externaldrive.fill", color: Theme.stripePurple, baseX: 0.78, size: 28, rotation: 6),
            TrashItem(symbol: "folder.fill",       color: Theme.stripeYellow, baseX: 0.88, size: 26, rotation: -10),
            TrashItem(symbol: "doc.zipper",        color: Theme.stripeGreen,  baseX: 0.68, size: 24, rotation: 14),
        ]
    }
}

// MARK: - The character + scene

struct MacBroomCharacter: View {
    let size: CGFloat       // character size
    let phase: CharacterPhase
    let onTap: () -> Void

    @StateObject private var mood = CharacterMood()
    @State private var trash: [TrashItem] = TrashItem.defaults()
    @State private var hiddenTrash: Set<UUID> = []
    @State private var charXRatio: CGFloat = 0.50
    @State private var facing: CGFloat = 1
    @State private var bob: CGFloat = 0
    @State private var hover: Bool = false
    @State private var rotation: Double = 0
    @State private var mouthOpen: Bool = false
    @State private var mouthTimer: Timer?
    @State private var idleWanderTimer: Timer?

    private let sceneHeight: CGFloat = 200

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                sceneBackground(width: geo.size.width)

                ForEach(trash) { item in
                    trashView(item, sceneWidth: geo.size.width)
                }

                characterView(sceneWidth: geo.size.width)
            }
            .frame(width: geo.size.width, height: sceneHeight)
        }
        .frame(height: sceneHeight)
        .onAppear { setupOnAppear() }
        .onDisappear { teardown() }
        .onChange(of: phase) { _, newPhase in
            handlePhase(newPhase)
        }
        .onChange(of: mood.message) { _, msg in
            mouthOpen = false
            mouthTimer?.invalidate()
            if msg != nil {
                mouthTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
                    Task { @MainActor in mouthOpen.toggle() }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
                    mouthTimer?.invalidate()
                    mouthOpen = false
                }
            }
        }
    }

    // MARK: - Scene background

    private func sceneBackground(width: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.96, blue: 0.91),
                    Color(red: 0.95, green: 0.89, blue: 0.78)
                ],
                startPoint: .top, endPoint: .bottom
            )
            // Floor strip
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.78, green: 0.66, blue: 0.50),
                             Color(red: 0.62, green: 0.52, blue: 0.38)],
                    startPoint: .top, endPoint: .bottom))
                .frame(height: 18)
            // Floor edge line
            Rectangle()
                .fill(Color.black.opacity(0.18))
                .frame(height: 1)
                .offset(y: -18)
        }
        .frame(width: width, height: sceneHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Trash

    private func trashView(_ item: TrashItem, sceneWidth: CGFloat) -> some View {
        let visible = !hiddenTrash.contains(item.id)
        let x = item.baseX * sceneWidth
        let y = sceneHeight - 18 - item.size * 0.55     // sit on the floor
        return Image(systemName: item.symbol)
            .font(.system(size: item.size, weight: .semibold))
            .foregroundStyle(item.color)
            .rotationEffect(.degrees(item.rotation))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 2)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.3)
            .position(x: x, y: y)
            .animation(.easeOut(duration: 0.4), value: hiddenTrash)
    }

    // MARK: - Character

    private func characterView(sceneWidth: CGFloat) -> some View {
        let charX = charXRatio * sceneWidth
        let charY = sceneHeight - 18 - size * 0.55      // stand on floor
        return ZStack {
            // Aura glow
            Circle()
                .fill(RadialGradient(
                    colors: [auraColor.opacity(auraIntensity), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.9))
                .frame(width: size * 1.7, height: size * 1.7)
                .blur(radius: 8)

            // Body button
            Button(action: onTap) {
                bodyView
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }

            // Speech bubble
            if let msg = mood.message {
                speechBubble(msg)
                    .offset(x: size * 0.55, y: -size * 0.65)
                    .transition(.scale(scale: 0.5, anchor: .bottomLeading).combined(with: .opacity))
            }
        }
        .position(x: charX, y: charY)
        .scaleEffect(x: facing, y: 1)
    }

    private var bodyView: some View {
        ZStack {
            AppIconView(size: size)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: auraColor.opacity(0.45), radius: 14, x: 0, y: 8)
                .scaleEffect((hover ? 1.05 : 1.0) * (phase.isReady ? 1.04 : 1.0))
                .rotationEffect(.degrees(rotation))
                .offset(y: bob == 1 ? -3 : 0)

            // Permanent glasses
            ThugLifeGlasses()
                .frame(width: size * 0.62, height: size * 0.22)
                .offset(y: -size * 0.05)

            // Mouth — animates when speaking
            mouthShape
                .offset(y: size * 0.10)
        }
    }

    private var mouthShape: some View {
        let mouthWidth = size * (mouthOpen ? 0.14 : 0.10)
        let mouthHeight = size * (mouthOpen ? 0.07 : 0.018)
        return Ellipse()
            .fill(Color.black.opacity(0.78))
            .frame(width: mouthWidth, height: mouthHeight)
            .animation(.easeInOut(duration: 0.10), value: mouthOpen)
    }

    private func speechBubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                BubbleShape()
                    .fill(LinearGradient(
                        colors: [Theme.stripeBlue, Theme.stripePurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
            )
            .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 3)
            .fixedSize()
            .scaleEffect(x: facing, y: 1)   // counter the parent flip so text reads correctly
    }

    // MARK: - Aura

    private var auraIntensity: CGFloat {
        switch phase {
        case .ready:    return 0.85
        case .cleaning: return 0.85
        case .scanning: return 0.60
        case .done:     return 0.40
        case .idle:     return 0.35
        }
    }
    private var auraColor: Color {
        switch phase {
        case .idle:     return Theme.stripeOrange
        case .scanning: return Theme.stripeBlue
        case .ready:    return Theme.stripeRed
        case .cleaning: return Theme.stripePurple
        case .done:     return Theme.stripeGreen
        }
    }

    // MARK: - Lifecycle

    private func setupOnAppear() {
        mood.update(phase: phase)
        mood.start()
        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
            bob = 1
        }
        startIdleWander()
    }

    private func teardown() {
        mood.stop()
        idleWanderTimer?.invalidate()
        mouthTimer?.invalidate()
    }

    private func handlePhase(_ newPhase: CharacterPhase) {
        mood.update(phase: newPhase)
        switch newPhase {
        case .idle, .ready, .done:
            withAnimation(.easeOut(duration: 0.4)) { rotation = 0 }
            if case .done = newPhase {
                // Trash stays cleared if previously cleaned. Reset for next scan.
            }
        case .scanning:
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            Task { await scanWalk() }
        case .cleaning:
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            Task { await cleanSequence() }
        }
    }

    // MARK: - Wander + clean sequence

    private func startIdleWander() {
        idleWanderTimer?.invalidate()
        idleWanderTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 6...12), repeats: true) { _ in
            Task { @MainActor in
                guard !phase.isWorking else { return }
                let target = CGFloat.random(in: 0.30...0.70)
                walk(to: target, duration: 1.6)
            }
        }
    }

    private func walk(to ratio: CGFloat, duration: Double) {
        let goingRight = ratio > charXRatio
        facing = goingRight ? 1 : -1
        withAnimation(.easeInOut(duration: duration)) {
            charXRatio = ratio
        }
    }

    /// During scanning, just wander around busily.
    private func scanWalk() async {
        for _ in 0..<3 {
            let target = CGFloat.random(in: 0.20...0.80)
            walk(to: target, duration: 0.8)
            try? await Task.sleep(nanoseconds: 850_000_000)
        }
    }

    /// During cleaning, walk to each trash item and make it disappear.
    private func cleanSequence() async {
        // Sort trash by x for left-to-right pass
        let order = trash.sorted { $0.baseX < $1.baseX }
        for item in order {
            walk(to: item.baseX, duration: 0.7)
            try? await Task.sleep(nanoseconds: 750_000_000)
            withAnimation(.easeOut(duration: 0.35)) {
                _ = hiddenTrash.insert(item.id)
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        // Walk back to center, stand proud
        walk(to: 0.50, duration: 0.8)
    }
}

// MARK: - Bubble shape

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let radius: CGFloat = 8
        let body = CGRect(x: 0, y: 0, width: rect.width, height: rect.height - 5)
        p.addRoundedRect(in: body, cornerSize: CGSize(width: radius, height: radius))
        let tailTop = CGPoint(x: 12, y: body.maxY)
        let tailBottom = CGPoint(x: 4, y: rect.height)
        let tailRight = CGPoint(x: 22, y: body.maxY)
        p.move(to: tailTop)
        p.addLine(to: tailBottom)
        p.addLine(to: tailRight)
        p.closeSubpath()
        return p
    }
}
