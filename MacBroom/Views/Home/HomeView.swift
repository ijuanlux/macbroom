import SwiftUI

private struct TrashPlacement: Identifiable, Hashable {
    let id = UUID()
    let sprite: [[Int]]
    var baseXRatio: CGFloat   // 0..1 across floor
    var state: State = .onFloor

    enum State: Hashable {
        case onFloor
        case carried          // in the character's hand, follows them
        case dropping         // mid-flight from hand to can
        case inCan            // landed in the trash can
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var coordinator = SmartScanCoordinator()

    @State private var trash: [TrashPlacement] = HomeView.defaultTrash()
    @State private var flyingItems: [UUID: CGPoint] = [:]   // current visual position during flight
    @State private var inCanCount: Int = 0
    @State private var charXRatio: CGFloat = 0.50
    @State private var facing: CGFloat = 1
    @State private var walkFrame: Int = 0
    @State private var walkTimer: Timer?
    @State private var isWalking: Bool = false
    @State private var message: String?
    @State private var messageTimer: Timer?
    @State private var idleTimer: Timer?
    @State private var overflowTimer: Timer?
    @State private var holdingBroom: Bool = false
    @State private var broomSwing: Int = 0
    @State private var broomTimer: Timer?
    @State private var carryingItem: UUID?
    @State private var lastCleanupCompletedAt: Date?
    @State private var isSitting: Bool = false
    @State private var legSwingFrame: Int = 0
    @State private var legSwingTimer: Timer?
    @State private var hasCoke: Bool = false
    @State private var cokeLifted: Bool = false
    @State private var cokeTimer: Timer?
    @State private var isListeningToMusic: Bool = false
    @State private var isDancing: Bool = false
    @State private var danceOffset: CGFloat = 0
    @State private var danceTimer: Timer?
    @State private var musicTask: Task<Void, Never>?
    @State private var hintText: String?
    @State private var hintTimer: Timer?
    @State private var hintPulse: Bool = false
    @AppStorage("macbroom.tutorialSeen") private var tutorialSeen: Bool = false
    private let chairXRatio: CGFloat = 0.42

    private let postSitMessages = [
        "uff, keep up the good work",
        "i deserve this",
        "much cleaner. nice.",
        "time for a sip",
        "MacBroom out.",
        "rest day earned",
    ]

    private let musicMessages = [
        "good tunes 🎵",
        "this beat slaps",
        "DJ apple in da house",
        "lemme cook 🎶",
        "1977 hits diff",
        "💿 mode",
    ]

    private let burpMessages = [
        "BUEEEERRRRP 💨",
        "*burp*",
        "BRAAAAP",
        "*pardon*",
        "ahhh that hits",
        "cold one 🥤",
        "uffffff",
        "💨 excuse me",
        "yeah baby",
    ]

    private let pixelScale: CGFloat = 6
    private let floorHeightRatio: CGFloat = 0.22
    /// Where the trash can sits, in scene-width ratio.
    private let canXRatio: CGFloat = 0.96
    /// Vertical position of the "mouth" of the trash can (ratio of scene height).
    private let canMouthYRatio: CGFloat = 0.70

    private let idleMessages = [
        "uff this mac is full of trash",
        "smart scan me bro",
        "imagine 50 GB of node_modules",
        "ready when you are 😎",
        "bored. clean me.",
        "tap me for the magic",
        "i was built different",
        "wanna sweep something?",
    ]
    private let cleaningMessages = [
        "sweep sweep sweep",
        "byebye trash",
        "delete delete delete",
        "almost done…",
    ]
    private let doneMessages = [
        "we did it 🧹",
        "feels lighter already",
        "next round?",
    ]
    private let overflowMessages = [
        "damn it, again",
        "ugh… seriously?",
        "this stuff multiplies",
        "i need a bigger can",
        "the trash gods hate me",
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                roomBackground(size: geo.size)
                chairView(sceneSize: geo.size)
                trashCanBackView(sceneSize: geo.size)
                trashMountainView(sceneSize: geo.size)
                trashCanFrontView(sceneSize: geo.size)
                ForEach(trash) { item in
                    trashView(item, sceneSize: geo.size)
                }
                characterView(sceneSize: geo.size)
                armOverlay(sceneSize: geo.size)
                if isListeningToMusic {
                    ipodView(sceneSize: geo.size)
                }
                if hasCoke && isSitting {
                    cokeView(sceneSize: geo.size)
                }
                tutorialHintView(sceneSize: geo.size)
                statusOverlay(sceneSize: geo.size)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear { currentSceneSize = geo.size }
            .onChange(of: geo.size) { _, s in currentSceneSize = s }
        }
        .background(Color.black.opacity(0.001))
        .onAppear(perform: setup)
        .onDisappear(perform: teardown)
        .onChange(of: coordinator.phase) { _, newPhase in
            handlePhase(newPhase)
        }
    }

    // MARK: - Background

    private func roomBackground(size: CGSize) -> some View {
        let floorH = size.height * floorHeightRatio
        return ZStack(alignment: .bottom) {
            wallpaper(size: size)
            // Top band: small flair (vinyl + polaroid + clock)
            vinylRecord
                .position(x: size.width * 0.05, y: size.height * 0.11)
            polaroid
                .position(x: size.width * 0.94, y: size.height * 0.11)
            clock
                .position(x: size.width * 0.42, y: size.height * 0.10)

            // Middle band: existing artwork
            picture
                .position(x: size.width * 0.14, y: size.height * 0.27)
            macBroomPoster
                .position(x: size.width * 0.58, y: size.height * 0.27)
            window
                .position(x: size.width * 0.80, y: size.height * 0.27)

            // Lower band: retro music + sci-fi posters (5 + sticky note)
            vPoster
                .position(x: size.width * 0.15, y: size.height * 0.50)
            acdcPoster
                .position(x: size.width * 0.27, y: size.height * 0.49)
            madonnaPoster
                .position(x: size.width * 0.39, y: size.height * 0.51)
            etPoster
                .position(x: size.width * 0.51, y: size.height * 0.49)
            bttfPoster
                .position(x: size.width * 0.63, y: size.height * 0.51)
            stickyNote
                .position(x: size.width * 0.74, y: size.height * 0.50)

            // Floor furniture
            bookshelf
                .position(x: size.width * 0.08, y: size.height - floorH - 50)
            plant
                .position(x: size.width * 0.88, y: size.height - floorH - 38)
            lamp
                .position(x: size.width * 0.30, y: size.height - floorH - 36)
            VStack(spacing: 0) {
                wainscoting(width: size.width)
                tiledFloor(width: size.width, height: floorH - 8)
            }
            .frame(width: size.width)
        }
        .frame(width: size.width, height: size.height)
    }

    private func wallpaper(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.86, green: 0.72, blue: 0.62),
                    Color(red: 0.94, green: 0.82, blue: 0.72)
                ],
                startPoint: .top, endPoint: .bottom
            )
            HStack(spacing: 0) {
                let stripeWidth: CGFloat = 36
                let count = Int((size.width / stripeWidth).rounded(.up)) + 1
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(i.isMultiple(of: 2) ? Color.white.opacity(0.06) : Color.clear)
                        .frame(width: stripeWidth)
                }
            }
            .frame(width: size.width)
        }
    }

    private func wainscoting(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color(red: 0.42, green: 0.28, blue: 0.14))
            .frame(height: 12)
    }

    private var picture: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.42, green: 0.28, blue: 0.14))
                .frame(width: 90, height: 64)
            Rectangle()
                .fill(LinearGradient(colors: Theme.rainbow,
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 78, height: 52)
            Circle().fill(Theme.stripeYellow).frame(width: 10, height: 10).offset(x: -22, y: -12)
        }
    }

    private var clock: some View {
        ZStack {
            Circle().fill(Color(red: 0.42, green: 0.28, blue: 0.14)).frame(width: 36, height: 36)
            Circle().fill(Color.white).frame(width: 30, height: 30)
            Capsule().fill(Color.black).frame(width: 2, height: 11).offset(y: -5)
            Capsule().fill(Color.black).frame(width: 2, height: 8).offset(x: 5, y: 0).rotationEffect(.degrees(90))
            Circle().fill(Color.black).frame(width: 3, height: 3)
        }
    }

    private var macBroomPoster: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.18, green: 0.16, blue: 0.20))
                .frame(width: 84, height: 70)
            VStack(spacing: 3) {
                Text("MAC")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.stripeOrange)
                Text("BROOM")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.stripeGreen)
                Text("'77")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.stripeYellow)
            }
        }
    }

    // MARK: - Retro wall details

    /// V (1983 sci-fi series) poster — giant red V on dark navy with VISITORS subtitle.
    private var vPoster: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.08, green: 0.06, blue: 0.10))
                .frame(width: 60, height: 80)
            Text("V")
                .font(.system(size: 52, weight: .black, design: .serif))
                .foregroundStyle(Color(red: 0.85, green: 0.16, blue: 0.18))
                .shadow(color: Color(red: 0.85, green: 0.16, blue: 0.18).opacity(0.7), radius: 5)
                .offset(y: -4)
            VStack {
                Spacer()
                Text("VISITORS")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .kerning(1.5)
                    .foregroundStyle(Color(red: 0.85, green: 0.16, blue: 0.18))
                    .padding(.bottom, 6)
            }
            .frame(width: 60, height: 80)
        }
        .frame(width: 60, height: 80)
        .clipped()
        .rotationEffect(.degrees(-3))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }

    /// AC/DC poster — black background, white serif text, yellow lightning bolt.
    private var acdcPoster: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
                .frame(width: 64, height: 80)
            HStack(spacing: 1) {
                Text("AC")
                    .font(.system(size: 20, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                LightningBolt()
                    .fill(Color(red: 0.98, green: 0.82, blue: 0.20))
                    .frame(width: 9, height: 20)
                    .shadow(color: Color(red: 0.98, green: 0.82, blue: 0.20).opacity(0.7), radius: 3)
                Text("DC")
                    .font(.system(size: 20, weight: .black, design: .serif))
                    .foregroundStyle(.white)
            }
            .offset(y: -4)
            VStack {
                Spacer()
                Text("HIGHWAY")
                    .font(.system(size: 5, weight: .black, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(.white)
                Text("TO HELL")
                    .font(.system(size: 5, weight: .black, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(Color(red: 0.98, green: 0.82, blue: 0.20))
                    .padding(.bottom, 5)
            }
            .frame(width: 64, height: 80)
        }
        .frame(width: 64, height: 80)
        .clipped()
        .rotationEffect(.degrees(2))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }

    /// Madonna 80s poster — hot pink with bold rounded white text.
    private var madonnaPoster: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.96, green: 0.38, blue: 0.66))
                .frame(width: 60, height: 80)
            // Diagonal black corner accent
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 30, y: 0))
                p.addLine(to: CGPoint(x: 0, y: 30))
                p.closeSubpath()
            }
            .fill(Color.black.opacity(0.85))
            .frame(width: 60, height: 80, alignment: .topLeading)
            Text("MADONNA")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 0.8)
                .rotationEffect(.degrees(-6))
                .offset(y: -16)
            VStack(spacing: 0) {
                Text("LIKE A")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("VIRGIN")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 0.5)
            }
            .offset(y: 8)
            Text("'84")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .offset(x: 20, y: 30)
        }
        .frame(width: 60, height: 80)
        .clipped()
        .rotationEffect(.degrees(-2))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }

    /// Vinyl record stuck on the wall — black disc with rainbow label.
    private var vinylRecord: some View {
        ZStack {
            Circle().fill(Color.black).frame(width: 54, height: 54)
            // Grooves
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.6)
                    .frame(width: CGFloat(48 - i * 6), height: CGFloat(48 - i * 6))
            }
            Circle()
                .fill(LinearGradient(colors: Theme.rainbow,
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 16, height: 16)
            Circle().fill(Color.black).frame(width: 2.5, height: 2.5)
        }
        .rotationEffect(.degrees(8))
        .shadow(color: .black.opacity(0.30), radius: 3, y: 2)
    }

    /// Polaroid pinned to the wall with a rainbow snapshot and "MEMORIES" caption.
    private var polaroid: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.white)
                .frame(width: 42, height: 52)
            Rectangle()
                .fill(LinearGradient(colors: Theme.rainbow,
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 34, height: 32)
                .offset(y: 4)
            VStack {
                Spacer()
                Text("MEMORIES")
                    .font(.system(size: 5, weight: .heavy, design: .monospaced))
                    .kerning(0.8)
                    .foregroundStyle(.black)
                    .padding(.bottom, 4)
            }
            .frame(width: 42, height: 52)
            // Tape strip at top
            Rectangle()
                .fill(Color(red: 0.95, green: 0.78, blue: 0.42).opacity(0.85))
                .frame(width: 18, height: 4)
                .rotationEffect(.degrees(-6))
                .offset(y: -3)
        }
        .rotationEffect(.degrees(-9))
        .shadow(color: .black.opacity(0.20), radius: 3, y: 2)
    }

    /// E.T. (1982) poster — bike silhouette over a giant moon, "PHONE HOME" tagline.
    private var etPoster: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.08, blue: 0.22),
                         Color(red: 0.14, green: 0.12, blue: 0.32)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 60, height: 80)

            // Title at the top
            VStack {
                Text("E.T.")
                    .font(.system(size: 16, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.4), radius: 2)
                    .padding(.top, 4)
                Spacer()
            }
            .frame(width: 60, height: 80)

            // Big moon + bike silhouette over it
            ZStack {
                Circle()
                    .fill(Color(red: 0.98, green: 0.92, blue: 0.55))
                    .frame(width: 34, height: 34)
                    .shadow(color: Color(red: 0.98, green: 0.92, blue: 0.55).opacity(0.55), radius: 6)
                // Bike with rider
                Image(systemName: "figure.outdoor.cycle")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.black)
            }
            .offset(y: -2)

            // Tagline at the bottom
            VStack {
                Spacer()
                Text("PHONE HOME")
                    .font(.system(size: 6, weight: .heavy, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 6)
            }
            .frame(width: 60, height: 80)
        }
        .frame(width: 60, height: 80)
        .clipped()
        .rotationEffect(.degrees(2))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }

    /// Back to the Future (1985) poster — orange/red sunset with OUTATIME plate.
    private var bttfPoster: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.62, blue: 0.10),
                         Color(red: 0.92, green: 0.20, blue: 0.10)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 60, height: 80)

            VStack(spacing: 0) {
                Text("BACK")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                Text("TO THE")
                    .font(.system(size: 6, weight: .heavy, design: .rounded))
                    .kerning(0.8)
                    .foregroundStyle(.white)
                Text("FUTURE")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.98, green: 0.92, blue: 0.45))
                    .shadow(color: .black, radius: 1)
            }
            .offset(y: -14)

            // Lightning bolt accent
            LightningBolt()
                .fill(Color(red: 0.98, green: 0.92, blue: 0.45))
                .frame(width: 8, height: 16)
                .offset(x: -22, y: 12)
                .shadow(color: Color(red: 0.98, green: 0.92, blue: 0.45).opacity(0.7), radius: 3)

            // OUTATIME license plate
            ZStack {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 46, height: 14)
                    .shadow(color: .black.opacity(0.4), radius: 1)
                Text("OUTATIME")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .kerning(0.6)
                    .foregroundStyle(Color(red: 0.78, green: 0.10, blue: 0.10))
            }
            .offset(y: 26)
        }
        .frame(width: 60, height: 80)
        .clipped()
        .rotationEffect(.degrees(-3))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }

    /// Hand-written yellow sticky note pinned to the wall.
    private var stickyNote: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.98, green: 0.93, blue: 0.45))
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
            // Curled corner
            Path { p in
                p.move(to: CGPoint(x: 42, y: 50))
                p.addLine(to: CGPoint(x: 50, y: 50))
                p.addLine(to: CGPoint(x: 50, y: 42))
                p.closeSubpath()
            }
            .fill(Color(red: 0.85, green: 0.78, blue: 0.30))
            .frame(width: 50, height: 50, alignment: .topLeading)

            VStack(spacing: 1) {
                Text("clean")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black.opacity(0.78))
                Text("ur mac")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black.opacity(0.78))
                Text("bro")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black.opacity(0.78))
            }
        }
        .rotationEffect(.degrees(5))
    }

    private var window: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.42, green: 0.28, blue: 0.14))
                .frame(width: 120, height: 90)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(Color(red: 0.55, green: 0.82, blue: 0.95))
                    Rectangle().fill(Color(red: 0.50, green: 0.78, blue: 0.93))
                }
                HStack(spacing: 0) {
                    Rectangle().fill(Color(red: 0.50, green: 0.78, blue: 0.93))
                    Rectangle().fill(Color(red: 0.45, green: 0.74, blue: 0.90))
                }
            }
            .frame(width: 108, height: 78)
            Circle().fill(Theme.stripeYellow).frame(width: 22, height: 22).offset(x: -28, y: -20)
            Rectangle().fill(Color(red: 0.42, green: 0.28, blue: 0.14)).frame(width: 108, height: 4)
            Rectangle().fill(Color(red: 0.42, green: 0.28, blue: 0.14)).frame(width: 4, height: 78)
        }
    }

    private var bookshelf: some View {
        VStack(spacing: 2) {
            bookshelfRow(rowIndex: 0)
            bookshelfRow(rowIndex: 1)
            bookshelfRow(rowIndex: 2)
            bookshelfRow(rowIndex: 3)
            Rectangle().fill(Color(red: 0.30, green: 0.18, blue: 0.08))
                .frame(height: 4)
        }
        .frame(width: 80, height: 110)
        .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
    }

    private func bookshelfRow(rowIndex: Int) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.42, green: 0.28, blue: 0.14))
                .frame(height: 22)
            HStack(spacing: 1) {
                ForEach(0..<6, id: \.self) { col in
                    let colorIdx = (rowIndex * 6 + col) % Theme.rainbow.count
                    let bookHeight: CGFloat = 14 + CGFloat((rowIndex + col) % 3) * 2
                    Rectangle()
                        .fill(Theme.rainbow[colorIdx])
                        .frame(width: 10, height: bookHeight)
                }
            }
            .padding(.bottom, 2)
        }
    }

    private var plant: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(Color(red: 0.30, green: 0.55, blue: 0.30))
                        .frame(width: 12, height: 36)
                        .rotationEffect(.degrees(Double(i - 2) * 22))
                        .offset(y: -12)
                }
            }
            .frame(width: 70, height: 50)
            Trapezoid()
                .fill(Color(red: 0.65, green: 0.42, blue: 0.20))
                .frame(width: 36, height: 26)
        }
        .frame(width: 70, height: 80)
        .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
    }

    private var lamp: some View {
        VStack(spacing: 0) {
            Trapezoid()
                .fill(Color(red: 0.95, green: 0.78, blue: 0.42))
                .frame(width: 38, height: 18)
            Rectangle().fill(Color(red: 0.42, green: 0.28, blue: 0.14)).frame(width: 4, height: 30)
            Rectangle().fill(Color(red: 0.30, green: 0.18, blue: 0.08)).frame(width: 22, height: 4)
        }
        .frame(width: 38, height: 56)
        .shadow(color: .black.opacity(0.20), radius: 3, y: 2)
    }

    private func tiledFloor(width: CGFloat, height: CGFloat) -> some View {
        let tile: CGFloat = 32
        let cols = Int((width / tile).rounded(.up)) + 1
        let rows = Int((height / tile).rounded(.up)) + 1
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(red: 0.78, green: 0.66, blue: 0.50))
            ForEach(0..<rows, id: \.self) { r in
                ForEach(0..<cols, id: \.self) { c in
                    if (r + c) % 2 == 0 {
                        Rectangle()
                            .fill(Color(red: 0.66, green: 0.54, blue: 0.40))
                            .frame(width: tile, height: tile)
                            .offset(x: CGFloat(c) * tile, y: CGFloat(r) * tile)
                    }
                }
            }
            Rectangle()
                .fill(Color.black.opacity(0.20))
                .frame(height: 2)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    // MARK: - Coke can (sipping animation)

    private func cokeView(sceneSize: CGSize) -> some View {
        // Coke is centered on the hand. The hand point itself moves up to the mouth
        // when cokeLifted (driven by handPosition).
        let hand = handPosition(sceneSize: sceneSize)
        let lifted = cokeLifted
        return PixelSprite(pixels: TrashSprites.cokeCan,
                           palette: TrashPalette.colors,
                           scale: pixelScale * 0.8)
            .rotationEffect(.degrees(lifted ? -32 * Double(facing) : 0))
            .position(x: hand.x, y: hand.y)
            .animation(.easeInOut(duration: 0.4), value: cokeLifted)
            .animation(.linear(duration: 0.35), value: charXRatio)
            .animation(.easeInOut(duration: 0.4), value: isSitting)
    }

    // MARK: - Chair

    private func chairView(sceneSize: CGSize) -> some View {
        let chairHeightPx = CGFloat(TrashSprites.chair.count) * pixelScale
        let floorY = sceneSize.height - sceneSize.height * floorHeightRatio
        return PixelSprite(pixels: TrashSprites.chair,
                           palette: TrashPalette.colors,
                           scale: pixelScale)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 3)
            .position(x: chairXRatio * sceneSize.width,
                      y: floorY - chairHeightPx / 2 + 4)
    }

    // MARK: - Trash can + mountain

    private var canHeightPx: CGFloat { CGFloat(TrashSprites.trashCanBack.count) * pixelScale }
    private var canWidthPx: CGFloat { CGFloat(TrashSprites.trashCanBack.first?.count ?? 14) * pixelScale }

    private func trashCanBackView(sceneSize: CGSize) -> some View {
        let floorY = sceneSize.height - sceneSize.height * floorHeightRatio
        let x = canXRatio * sceneSize.width
        let y = floorY - canHeightPx / 2 + 4
        return PixelSprite(pixels: TrashSprites.trashCanBack,
                           palette: TrashPalette.colors,
                           scale: pixelScale)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
            .position(x: x, y: y)
    }

    private func trashCanFrontView(sceneSize: CGSize) -> some View {
        let floorY = sceneSize.height - sceneSize.height * floorHeightRatio
        let x = canXRatio * sceneSize.width
        let y = floorY - canHeightPx / 2 + 4
        return PixelSprite(pixels: TrashSprites.trashCanFront,
                           palette: TrashPalette.colors,
                           scale: pixelScale)
            .position(x: x, y: y)
    }

    /// Pile of trash inside the wire-mesh can (drawn between back and front mesh).
    private func trashMountainView(sceneSize: CGSize) -> some View {
        let floorY = sceneSize.height - sceneSize.height * floorHeightRatio
        let canBaseY = floorY - pixelScale * 2          // base inside the can
        let canX = canXRatio * sceneSize.width
        let pieces = min(inCanCount, 14)
        return ZStack {
            ForEach(0..<pieces, id: \.self) { i in
                pieceSprite(i)
                    .offset(
                        x: CGFloat((i * 7) % Int(canWidthPx - 28)) - canWidthPx / 2 + 16,
                        y: -CGFloat(i) * 7 - pixelScale * 2
                    )
            }
        }
        .position(x: canX, y: canBaseY)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: inCanCount)
    }

    @ViewBuilder
    private func pieceSprite(_ index: Int) -> some View {
        let sprites = [
            TrashSprites.banana, TrashSprites.paper, TrashSprites.can,
            TrashSprites.cassette, TrashSprites.sock, TrashSprites.floppy
        ]
        PixelSprite(
            pixels: sprites[index % sprites.count],
            palette: TrashPalette.colors,
            scale: pixelScale * 0.55
        )
        .rotationEffect(.degrees(Double((index * 47) % 60) - 30))
    }

    // MARK: - Trash items

    private func trashView(_ item: TrashPlacement, sceneSize: CGSize) -> some View {
        let position = trashPosition(item, sceneSize: sceneSize)
        let visible: Bool = {
            switch item.state {
            case .onFloor, .carried, .dropping: return true
            case .inCan:                         return false
            }
        }()
        // Only auto-animate when state is .onFloor (e.g. overflow reposition).
        // Carried follows the character; dropping is driven frame-by-frame.
        let useImplicitAnim = item.state == .onFloor
        return PixelSprite(pixels: item.sprite, palette: TrashPalette.colors, scale: pixelScale)
            .opacity(visible ? 1 : 0)
            .scaleEffect(item.state == .carried || item.state == .dropping ? 0.8 : 1.0)
            .position(position)
            .animation(useImplicitAnim ? .easeOut(duration: 0.4) : nil, value: position)
            .animation(.easeOut(duration: 0.3), value: visible)
    }

    private func trashPosition(_ item: TrashPlacement, sceneSize: CGSize) -> CGPoint {
        let spriteHeight = CGFloat(item.sprite.count) * pixelScale
        let floorY = sceneSize.height - sceneSize.height * floorHeightRatio
        switch item.state {
        case .onFloor:
            return CGPoint(
                x: item.baseXRatio * sceneSize.width,
                y: floorY - spriteHeight / 2 + 2
            )
        case .carried:
            // Held next to the character at "hand" height
            return handPosition(sceneSize: sceneSize)
        case .dropping:
            return flyingItems[item.id] ?? handPosition(sceneSize: sceneSize)
        case .inCan:
            return CGPoint(x: canXRatio * sceneSize.width, y: sceneSize.height * canMouthYRatio)
        }
    }

    /// Position of the character's front hand for the current state.
    /// Single source of truth — used for trash carry, coke hold/sip, basket throws,
    /// and the front-arm endpoint in `armOverlay`. Accounts for sit + dance offsets.
    private func handPosition(sceneSize: CGSize) -> CGPoint {
        let charSpriteHeight = CGFloat(AppleSprites.idle.count) * pixelScale
        let floorY = sceneSize.height - sceneSize.height * floorHeightRatio
        let sitYOffset: CGFloat = isSitting ? -pixelScale * 2 : 0
        let sitXOffset: CGFloat = isSitting ? pixelScale * 2 : 0
        let charX = charXRatio * sceneSize.width + sitXOffset + danceOffset
        let charCenterY = floorY - charSpriteHeight / 2 + pixelScale * 2 + sitYOffset
        let shoulderY = charCenterY - pixelScale * 1

        if carryingItem != nil {
            // Reaching out in front to hold trash, mid-body height.
            return CGPoint(x: charX + facing * pixelScale * 9, y: charCenterY)
        }
        if isListeningToMusic {
            // Chest level holding the iPod.
            return CGPoint(x: charX + facing * pixelScale * 11, y: charCenterY)
        }
        if isSitting && hasCoke && cokeLifted {
            // Raised toward the mouth — top of the can lands at the red mouth row.
            return CGPoint(x: charX + facing * pixelScale * 3, y: charCenterY + pixelScale * 4)
        }
        if isSitting && hasCoke {
            // Resting at the lap, slightly out from the body.
            return CGPoint(x: charX + facing * pixelScale * 6, y: charCenterY + pixelScale * 7)
        }
        // Idle hanging at the side.
        return CGPoint(x: charX + facing * pixelScale * 8, y: shoulderY + pixelScale * 6)
    }

    // MARK: - Character

    private func characterView(sceneSize: CGSize) -> some View {
        let pixels = currentFrame
        let spriteHeight = CGFloat(pixels.count) * pixelScale
        let floorY = sceneSize.height - sceneSize.height * floorHeightRatio
        // Sit: butt rests on the chair seat (small lift, plus a few px right onto the seat).
        let sitYOffset: CGFloat = isSitting ? -pixelScale * 2 : 0
        let sitXOffset: CGFloat = isSitting ? pixelScale * 2 : 0
        let charX = charXRatio * sceneSize.width + sitXOffset + danceOffset
        let charY = floorY - spriteHeight / 2 + pixelScale * 2 + sitYOffset
        return ZStack(alignment: .topLeading) {
            // Broom on the back side (opposite of facing) — visible even when carrying.
            if holdingBroom {
                broomView
                    .offset(x: pixelScale * (facing > 0 ? -3 : 14), y: pixelScale * 11)
            }
            ZStack(alignment: .topLeading) {
                PixelSprite(pixels: pixels, palette: CharacterPalette.colors, scale: pixelScale)
                    .shadow(color: Theme.stripeOrange.opacity(0.55), radius: 16)
                if isListeningToMusic {
                    PixelSprite(pixels: HeadphoneSprites.dj,
                                palette: CharacterPalette.colors,
                                scale: pixelScale)
                        .offset(x: -pixelScale * 2, y: pixelScale * 4)
                        .transition(.opacity)
                }
            }
            .scaleEffect(x: facing, y: 1)
        }
        .position(x: charX, y: charY)
        .animation(.linear(duration: 0.35), value: charXRatio)
        .animation(.easeInOut(duration: 0.4), value: isSitting)
        .animation(.easeInOut(duration: 0.18), value: danceOffset)
        .onTapGesture { triggerPrimaryAction() }
    }

    /// iPod held in the front hand during music breaks. Position matches the
    /// music-mode branch of `handPosition` so iPod + fist + body move as one piece.
    private func ipodView(sceneSize: CGSize) -> some View {
        let hand = handPosition(sceneSize: sceneSize)
        return PixelSprite(pixels: MusicSprites.ipod,
                           palette: CharacterPalette.colors,
                           scale: pixelScale * 0.9)
            .position(x: hand.x, y: hand.y)
            .transition(.opacity)
            .animation(.linear(duration: 0.35), value: charXRatio)
            .animation(.easeInOut(duration: 0.4), value: isSitting)
            .animation(.easeInOut(duration: 0.18), value: danceOffset)
    }

    /// Scene-level arm overlay: draws both arms with positions that depend on state.
    /// Shoulders sit at the orange band (row ~14 of the apple body — below the glasses)
    /// so arms read as part of the body rather than sprouting from the face.
    /// - Front arm: idle = hangs at side; carrying = reaches to the held item;
    ///   listening to music = up at chest level holding iPod.
    /// - Back arm: idle = hangs; holding broom = grips the shaft.
    private func armOverlay(sceneSize: CGSize) -> some View {
        let charSpriteHeight = CGFloat(AppleSprites.idle.count) * pixelScale
        let floorY = sceneSize.height - sceneSize.height * floorHeightRatio
        let sitYOffset: CGFloat = isSitting ? -pixelScale * 2 : 0
        let sitXOffset: CGFloat = isSitting ? pixelScale * 2 : 0
        let charX = charXRatio * sceneSize.width + sitXOffset + danceOffset
        let charCenterY = floorY - charSpriteHeight / 2 + pixelScale * 2 + sitYOffset
        // Shoulder at the orange band (~row 14 of 30) — just below the glasses.
        let shoulderY = charCenterY - pixelScale * 1
        let shoulderOffset: CGFloat = pixelScale * 7
        let frontShoulder = CGPoint(x: charX + facing * shoulderOffset, y: shoulderY)
        let backShoulder = CGPoint(x: charX - facing * shoulderOffset, y: shoulderY)

        // Single source of truth: handPosition() already encodes state.
        let frontHand = handPosition(sceneSize: sceneSize)

        let backHand: CGPoint = {
            if holdingBroom {
                return CGPoint(x: backShoulder.x - facing * pixelScale * 1,
                               y: shoulderY + pixelScale * 4)
            }
            return CGPoint(x: backShoulder.x - facing * pixelScale * 1,
                           y: shoulderY + pixelScale * 6)
        }()

        return ZStack {
            armSegment(from: backShoulder, to: backHand, isBack: true)
            armSegment(from: frontShoulder, to: frontHand, isBack: false)
        }
        // Match characterView so the whole figure moves as a single piece.
        .animation(.linear(duration: 0.35), value: charXRatio)
        .animation(.easeInOut(duration: 0.4), value: isSitting)
        .animation(.easeInOut(duration: 0.18), value: danceOffset)
    }

    private func armSegment(from start: CGPoint, to end: CGPoint, isBack: Bool) -> some View {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(pixelScale * 2, sqrt(dx * dx + dy * dy))
        let angle = atan2(dy, dx)
        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2
        return ZStack {
            // Forearm — skin
            Rectangle()
                .fill(CharacterPalette.colors[10])
                .frame(width: length, height: pixelScale * 2)
                .rotationEffect(.radians(angle))
                .position(x: midX, y: midY)
            // Fist — dark
            Rectangle()
                .fill(CharacterPalette.colors[13])
                .frame(width: pixelScale * 2, height: pixelScale * 2)
                .position(x: end.x, y: end.y)
        }
        .opacity(isBack ? 0.82 : 1.0)
    }

    private var currentFrame: [[Int]] {
        if isSitting {
            return legSwingFrame == 0 ? AppleSprites.walkA : AppleSprites.walkB
        }
        if isWalking {
            return walkFrame == 0 ? AppleSprites.walkA : AppleSprites.walkB
        }
        return AppleSprites.idle
    }

    private var broomView: some View {
        let pixels = broomSwing == 0 ? BroomSprites.still : BroomSprites.swingA
        return PixelSprite(pixels: pixels, palette: CharacterPalette.colors, scale: pixelScale)
            .scaleEffect(x: facing, y: 1)
    }

    // MARK: - Tutorial hint

    /// Floating Flipper-style bubble above the character pointing down at it.
    /// Drives onboarding ("CLICK MACBROOM TO SCAN") and ready-state hand-off
    /// ("CLICK AGAIN TO CLEAN"). Hides on interaction; pulses to draw the eye.
    private func tutorialHintView(sceneSize: CGSize) -> some View {
        let charSpriteHeight = CGFloat(AppleSprites.idle.count) * pixelScale
        let floorY = sceneSize.height - sceneSize.height * floorHeightRatio
        let sitYOffset: CGFloat = isSitting ? -pixelScale * 2 : 0
        let sitXOffset: CGFloat = isSitting ? pixelScale * 2 : 0
        let charX = charXRatio * sceneSize.width + sitXOffset + danceOffset
        let charTopY = floorY - charSpriteHeight + pixelScale * 2 + sitYOffset
        let visible = hintText != nil
        return ZStack {
            if let text = hintText {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(text.uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color(red: 0.10, green: 0.10, blue: 0.14).opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(LinearGradient.rainbow, lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
                    HintArrow()
                        .fill(Color(red: 0.10, green: 0.10, blue: 0.14).opacity(0.92))
                        .frame(width: 14, height: 8)
                        .overlay(
                            HintArrow()
                                .stroke(LinearGradient.rainbow, lineWidth: 1.5)
                        )
                        .offset(y: -1)
                }
                .scaleEffect(hintPulse ? 1.04 : 1.0)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .opacity(visible ? 1 : 0)
        .position(x: charX, y: charTopY - 30)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: hintPulse)
        .animation(.easeOut(duration: 0.35), value: hintText)
        .allowsHitTesting(false)
    }

    private func showHint(_ text: String, after delay: Double = 0) {
        hintTimer?.invalidate()
        hintTimer = Timer.scheduledTimer(withTimeInterval: max(0.01, delay), repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.3)) { hintText = text }
                hintPulse = true
            }
        }
    }

    private func hideHint() {
        hintTimer?.invalidate()
        hintTimer = nil
        withAnimation(.easeIn(duration: 0.25)) { hintText = nil }
        hintPulse = false
    }

    // MARK: - Status overlay

    private func statusOverlay(sceneSize: CGSize) -> some View {
        HStack(spacing: 8) {
            Text("HOME")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(LinearGradient.rainbow))
            Text(statusLine)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 2)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .position(x: 140, y: 36)
        .overlay(alignment: .topLeading) {
            if let message {
                speechBubble(message)
                    .position(x: charXRatio * sceneSize.width + 60,
                              y: sceneSize.height - sceneSize.height * floorHeightRatio - 130)
                    .transition(.opacity.combined(with: .scale(scale: 0.5, anchor: .bottom)))
            }
        }
    }

    private var statusLine: String {
        switch coordinator.phase {
        case .idle:                          return "Tap the apple to scan"
        case .scanning:                      return "Scanning…"
        case .ready(let b, let c):           return "\(FileSystemUtils.formatBytes(b)) · \(c) items"
        case .cleaning:                      return "Sweeping…"
        case .done(let b) where b > 0:       return "Reclaimed \(FileSystemUtils.formatBytes(b))"
        case .done:                          return "Already clean"
        }
    }

    private func speechBubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.stripeBlue, Theme.stripePurple],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: .black.opacity(0.4), radius: 5, y: 3)
            .fixedSize()
    }

    // MARK: - Setup + teardown

    private func setup() {
        startWalkAnimation()
        startBroomSwing()
        startIdleBehavior()
        startOverflowTimer()
        // First-time onboarding hint
        if !tutorialSeen {
            showHint("Click MacBroom to scan", after: 1.5)
        }
    }

    private func teardown() {
        walkTimer?.invalidate()
        broomTimer?.invalidate()
        idleTimer?.invalidate()
        messageTimer?.invalidate()
        overflowTimer?.invalidate()
        legSwingTimer?.invalidate()
        cokeTimer?.invalidate()
        danceTimer?.invalidate()
        musicTask?.cancel()
        hintTimer?.invalidate()
    }

    private func startWalkAnimation() {
        walkTimer?.invalidate()
        walkTimer = Timer.scheduledTimer(withTimeInterval: 0.20, repeats: true) { _ in
            Task { @MainActor in walkFrame = (walkFrame + 1) % 2 }
        }
    }

    private func startBroomSwing() {
        broomTimer?.invalidate()
        broomTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { _ in
            Task { @MainActor in broomSwing = (broomSwing + 1) % 2 }
        }
    }

    private func startIdleBehavior() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 6...10), repeats: true) { _ in
            Task { @MainActor in
                guard !coordinator.phase.isWorkingPhase else { return }
                guard !isListeningToMusic else { return }
                guard !isSitting else { return }
                // 25% music, 35% walk, 40% speak
                let roll = Double.random(in: 0...1)
                if roll < 0.25 {
                    musicTask?.cancel()
                    musicTask = Task { await musicBreak() }
                } else if roll < 0.60 {
                    let target = CGFloat.random(in: 0.20...0.70)
                    walk(to: target, duration: 1.6)
                } else {
                    speak(idleMessages.randomElement() ?? "hey")
                }
            }
        }
    }

    // MARK: - Music break + dance

    private func musicBreak() async {
        // Pull out the iPod + put on headphones with a small intro.
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.25)) {
                isListeningToMusic = true
            }
        }
        try? await Task.sleep(nanoseconds: 700_000_000)
        speak(musicMessages.randomElement() ?? "🎵", duration: 2.5)
        try? await Task.sleep(nanoseconds: 400_000_000)
        await MainActor.run { isDancing = true }
        startDanceTimer()
        // Dance for ~6s
        try? await Task.sleep(nanoseconds: 6_200_000_000)
        stopDanceTimer()
        await MainActor.run {
            isDancing = false
            withAnimation(.easeInOut(duration: 0.25)) { danceOffset = 0 }
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        await MainActor.run {
            withAnimation(.easeIn(duration: 0.3)) {
                isListeningToMusic = false
            }
        }
    }

    private func startDanceTimer() {
        danceTimer?.invalidate()
        var step = 0
        danceTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { _ in
            Task { @MainActor in
                step += 1
                let cycle = step % 4
                let target: CGFloat
                switch cycle {
                case 0: target = -pixelScale
                case 1: target = 0
                case 2: target = pixelScale
                default: target = 0
                }
                withAnimation(.easeInOut(duration: 0.16)) { danceOffset = target }
            }
        }
    }

    private func stopDanceTimer() {
        danceTimer?.invalidate()
        danceTimer = nil
    }

    private func cancelMusicBreakIfActive() {
        musicTask?.cancel()
        musicTask = nil
        stopDanceTimer()
        if isListeningToMusic || isDancing || danceOffset != 0 {
            withAnimation(.easeOut(duration: 0.2)) {
                isListeningToMusic = false
                isDancing = false
                danceOffset = 0
            }
        }
    }

    // Trash overflow — items in the can fall back out one by one
    private func startOverflowTimer() {
        overflowTimer?.invalidate()
        // Slower base interval + always wait at least 45s after the last cleanup
        overflowTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 35...55), repeats: true) { _ in
            Task { @MainActor in
                guard !coordinator.phase.isWorkingPhase else { return }
                if let last = lastCleanupCompletedAt,
                   Date().timeIntervalSince(last) < 45 { return }
                overflowOneItem()
            }
        }
    }

    private func overflowOneItem() {
        guard let firstIdx = trash.firstIndex(where: { $0.state == .inCan }) else { return }
        let newRatio = CGFloat.random(in: 0.18...0.82)
        trash[firstIdx].state = .onFloor
        trash[firstIdx].baseXRatio = newRatio
        inCanCount = max(0, inCanCount - 1)
        speak(overflowMessages.randomElement() ?? "damn it")
    }

    // MARK: - Walk + clean

    private func walk(to ratio: CGFloat, duration: Double) {
        let goingRight = ratio > charXRatio
        facing = goingRight ? 1 : -1
        isWalking = true
        withAnimation(.linear(duration: duration)) {
            charXRatio = ratio
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            isWalking = false
        }
    }

    private func handlePhase(_ newPhase: SmartScanCoordinator.Phase) {
        switch newPhase {
        case .scanning:
            cancelMusicBreakIfActive()
            hideHint()
            speak("sniffing your library…")
            Task { await scanWalk() }
        case .cleaning:
            cancelMusicBreakIfActive()
            hideHint()
            holdingBroom = true
            Task { await cleanSequence() }
        case .done(let bytes):
            holdingBroom = false
            lastCleanupCompletedAt = Date()
            if bytes > 0 { speak(doneMessages.randomElement() ?? "done") }
        case .ready:
            speak("look at all this junk")
            // Contextual hand-off — always show, even after the first run.
            showHint("Click again for a quick win", after: 0.7)
        case .idle:
            break
        }
    }

    private func scanWalk() async {
        for _ in 0..<3 {
            let target = CGFloat.random(in: 0.20...0.80)
            walk(to: target, duration: 0.9)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func cleanSequence() async {
        speak(cleaningMessages.randomElement() ?? "sweep")
        isSitting = false
        let order = trash.enumerated()
            .filter { $0.element.state == .onFloor }
            .sorted { $0.element.baseXRatio < $1.element.baseXRatio }

        for (idx, _) in order {
            let item = trash[idx]
            await walkAndWait(to: item.baseXRatio, duration: 0.42)
            await MainActor.run {
                trash[idx].state = .carried
                carryingItem = item.id
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
            // 18% chance to attempt a basket shot from where the character is
            if Bool.random() && Bool.random() && Bool.random() {  // ~12.5%
                await basketShot(idx: idx)
            } else {
                await walkAndWait(to: canXRatio - 0.06, duration: 0.48)
                await dropIntoCan(idx: idx)
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        // After cleanup → walk to the chair and sit + grab a coke
        await walkAndWait(to: chairXRatio, duration: 0.55)
        await MainActor.run {
            isSitting = true
            hasCoke = true
        }
        startLegSwingTimer()
        startCokeSippingTimer()
        try? await Task.sleep(nanoseconds: 600_000_000)
        speak(postSitMessages.randomElement() ?? "ahhh", duration: 4.0)
    }

    /// Periodically raises the arm + can to the mouth, sips, lowers back to the lap,
    /// and follows ~60% of sips with a burp message.
    private func startCokeSippingTimer() {
        cokeTimer?.invalidate()
        cokeTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 3.5...6.0), repeats: true) { _ in
            Task { @MainActor in
                guard isSitting else { return }
                // Raise can to mouth (handPosition shifts up because cokeLifted = true)
                withAnimation(.easeInOut(duration: 0.45)) { cokeLifted = true }
                try? await Task.sleep(nanoseconds: 850_000_000)
                // Lower back to the lap
                withAnimation(.easeInOut(duration: 0.45)) { cokeLifted = false }
                try? await Task.sleep(nanoseconds: 550_000_000)
                guard isSitting else { return }
                // ~60% of sips → burp
                if Double.random(in: 0...1) < 0.6 {
                    speak(burpMessages.randomElement() ?? "*burp*", duration: 2.3)
                }
            }
        }
    }

    private func stopCokeSippingTimer() {
        cokeTimer?.invalidate()
        cokeTimer = nil
    }

    private let basketHitPhrases = [
        "KOBE!",
        "swish 🏀",
        "nothing but net",
        "3 pointer baby",
        "and one!",
    ]
    private let basketMissPhrases = [
        "damn missed",
        "rim shot",
        "no good",
        "ugh, again",
        "i'll pick it up",
    ]

    private func basketShot(idx: Int) async {
        guard let geo = currentSceneSize else { return }
        let item = trash[idx]
        let start = handPosition(sceneSize: geo)
        let willHit = Double.random(in: 0...1) < 0.55
        let phrase = (willHit ? basketHitPhrases : basketMissPhrases).randomElement() ?? "shoot"
        speak(phrase, duration: 2.0)

        let floorY = geo.height - geo.height * floorHeightRatio
        let landing: CGPoint
        if willHit {
            landing = CGPoint(x: canXRatio * geo.width, y: geo.height * canMouthYRatio)
        } else {
            let missRatio = CGFloat.random(in: 0.20...0.85)
            landing = CGPoint(x: missRatio * geo.width, y: floorY - pixelScale * 6)
        }
        let peak = CGPoint(
            x: (start.x + landing.x) / 2,
            y: min(start.y, landing.y) - 130
        )

        await MainActor.run {
            trash[idx].state = .dropping
            flyingItems[item.id] = start
            carryingItem = nil
        }

        // Frame-by-frame parabolic bezier — 30 frames over ~700ms.
        let totalFrames = 30
        for frame in 1...totalFrames {
            let t = CGFloat(frame) / CGFloat(totalFrames)
            let oneMinus = 1 - t
            let x = oneMinus * oneMinus * start.x + 2 * oneMinus * t * peak.x + t * t * landing.x
            let y = oneMinus * oneMinus * start.y + 2 * oneMinus * t * peak.y + t * t * landing.y
            await MainActor.run { flyingItems[item.id] = CGPoint(x: x, y: y) }
            try? await Task.sleep(nanoseconds: 22_000_000)
        }

        await MainActor.run {
            if willHit {
                trash[idx].state = .inCan
                inCanCount += 1
            } else {
                trash[idx].baseXRatio = landing.x / geo.width
                trash[idx].state = .onFloor
            }
            flyingItems.removeValue(forKey: item.id)
        }
    }

    private func standUpThenScan() async {
        // Smooth: drop coke, leave the chair with a short step, then scan
        withAnimation(.easeOut(duration: 0.35)) {
            hasCoke = false
        }
        stopCokeSippingTimer()
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.easeInOut(duration: 0.4)) {
            isSitting = false
        }
        stopLegSwingTimer()
        // Take a small step off the chair before scanning
        try? await Task.sleep(nanoseconds: 350_000_000)
        await walkAndWait(to: chairXRatio + 0.05, duration: 0.45)
        await coordinator.scan()
    }

    private func startLegSwingTimer() {
        legSwingTimer?.invalidate()
        legSwingTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            Task { @MainActor in legSwingFrame = (legSwingFrame + 1) % 2 }
        }
    }

    private func stopLegSwingTimer() {
        legSwingTimer?.invalidate()
        legSwingTimer = nil
    }

    private func walkAndWait(to ratio: CGFloat, duration: Double) async {
        walk(to: ratio, duration: duration)
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 30_000_000)
    }

    private func dropIntoCan(idx: Int) async {
        guard let geo = currentSceneSize else { return }
        let item = trash[idx]
        let start = handPosition(sceneSize: geo)
        let landing = CGPoint(x: canXRatio * geo.width, y: geo.height * canMouthYRatio)
        // Small arc — peak ~60px above the higher of start/landing.
        let peak = CGPoint(
            x: (start.x + landing.x) / 2,
            y: min(start.y, landing.y) - 60
        )
        await MainActor.run {
            trash[idx].state = .dropping
            flyingItems[item.id] = start
            carryingItem = nil
        }
        let totalFrames = 22
        for frame in 1...totalFrames {
            let t = CGFloat(frame) / CGFloat(totalFrames)
            let oneMinus = 1 - t
            let x = oneMinus * oneMinus * start.x + 2 * oneMinus * t * peak.x + t * t * landing.x
            let y = oneMinus * oneMinus * start.y + 2 * oneMinus * t * peak.y + t * t * landing.y
            await MainActor.run { flyingItems[item.id] = CGPoint(x: x, y: y) }
            try? await Task.sleep(nanoseconds: 22_000_000)
        }
        await MainActor.run {
            trash[idx].state = .inCan
            inCanCount += 1
            flyingItems.removeValue(forKey: item.id)
        }
    }

    @State private var currentSceneSize: CGSize?
    // Capture size via a hidden GeometryReader overlay
    private func captureSize() -> some View {
        GeometryReader { geo in
            Color.clear.onAppear { currentSceneSize = geo.size }
            Color.clear.onChange(of: geo.size) { _, s in currentSceneSize = s }
        }
    }

    private func speak(_ text: String, duration: Double = 3.5) {
        withAnimation(.easeOut(duration: 0.2)) { message = text }
        messageTimer?.invalidate()
        messageTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeIn(duration: 0.3)) { message = nil }
            }
        }
    }

    // MARK: - Tap action

    private func triggerPrimaryAction() {
        // First successful tap dismisses onboarding permanently.
        if !tutorialSeen { tutorialSeen = true }
        hideHint()
        switch coordinator.phase {
        case .idle, .done:
            if isSitting {
                Task { await standUpThenScan() }
                return
            }
            Task { await coordinator.scan() }
        case .ready:
            Task {
                let reclaimed = await coordinator.cleanAll()
                appState.signalCleanup(reclaimed: reclaimed)
            }
        case .scanning, .cleaning:
            break
        }
    }

    private static func defaultTrash() -> [TrashPlacement] {
        [
            TrashPlacement(sprite: TrashSprites.box,      baseXRatio: 0.18),
            TrashPlacement(sprite: TrashSprites.paper,    baseXRatio: 0.24),
            TrashPlacement(sprite: TrashSprites.banana,   baseXRatio: 0.32),
            TrashPlacement(sprite: TrashSprites.cassette, baseXRatio: 0.40),
            TrashPlacement(sprite: TrashSprites.mug,      baseXRatio: 0.46),
            TrashPlacement(sprite: TrashSprites.sock,     baseXRatio: 0.52),
            TrashPlacement(sprite: TrashSprites.pizzaBox, baseXRatio: 0.60),
            TrashPlacement(sprite: TrashSprites.floppy,   baseXRatio: 0.66),
            TrashPlacement(sprite: TrashSprites.bottle,   baseXRatio: 0.72),
            TrashPlacement(sprite: TrashSprites.can,      baseXRatio: 0.78),
            TrashPlacement(sprite: TrashSprites.paper,    baseXRatio: 0.84),
        ]
    }
}

/// Stylized lightning bolt used in the AC/DC poster.
private struct LightningBolt: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX + rect.width * 0.20, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY * 1.05))
        p.addLine(to: CGPoint(x: rect.midX * 0.85, y: rect.midY * 1.05))
        p.addLine(to: CGPoint(x: rect.midX * 0.30, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY * 0.85))
        p.addLine(to: CGPoint(x: rect.midX * 1.20, y: rect.midY * 0.85))
        p.closeSubpath()
        return p
    }
}

/// Downward-pointing triangle used as the tutorial hint's tail.
private struct HintArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.closeSubpath()
        return p
    }
}

private struct Trapezoid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * 0.18
        p.move(to: CGPoint(x: inset, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: 0, y: 0))
        p.closeSubpath()
        return p
    }
}

private extension SmartScanCoordinator.Phase {
    var isWorkingPhase: Bool {
        switch self {
        case .scanning, .cleaning: return true
        default: return false
        }
    }
}
