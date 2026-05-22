import SwiftUI

struct OnboardingBullet: Identifiable {
    let id = UUID()
    let systemImage: String
    let text: String
}

struct OnboardingCard: Identifiable {
    let id = UUID()
    let kicker: String?      // small label above the title
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let bullets: [OnboardingBullet]
}

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var index: Int = 0
    @State private var direction: CGFloat = 1   // 1 = next, -1 = back

    private let cards: [OnboardingCard] = [
        OnboardingCard(
            kicker: "v0.6.0",
            title: "Welcome to MacBroom",
            subtitle: "A free, open-source Mac cleaner with personality. CleanMyMac vibes, zero paywall.",
            systemImage: "wind",
            tint: Theme.stripeOrange,
            bullets: [
                OnboardingBullet(systemImage: "checkmark.shield.fill", text: "100% local. No tracking, no telemetry"),
                OnboardingBullet(systemImage: "chevron.left.forwardslash.chevron.right", text: "Open source — read every line"),
                OnboardingBullet(systemImage: "heart.fill", text: "Built different. Built for the homies"),
            ]
        ),
        OnboardingCard(
            kicker: "Home",
            title: "Meet your apple",
            subtitle: "The character on Home isn't just decoration — he actually sweeps your Mac. Click him and watch.",
            systemImage: "apple.logo",
            tint: Theme.stripeRed,
            bullets: [
                OnboardingBullet(systemImage: "hand.tap.fill", text: "Tap to scan + clean in one go"),
                OnboardingBullet(systemImage: "trash.fill", text: "He carries trash to the can (and sometimes shoots a basket)"),
                OnboardingBullet(systemImage: "headphones", text: "Idle moods: DJ mode, sit + sip a coke, dance"),
            ]
        ),
        OnboardingCard(
            kicker: "Smart Scan",
            title: "Find the gunk in one click",
            subtitle: "Targets the boring stuff that piles up while you sleep. Caches, dev junk, big files, duplicates — all in one sweep.",
            systemImage: "sparkles",
            tint: Theme.stripeGreen,
            bullets: [
                OnboardingBullet(systemImage: "externaldrive.badge.minus", text: "User + system caches, log files, temp dirs"),
                OnboardingBullet(systemImage: "hammer.fill", text: "node_modules, DerivedData, .gradle, Pods"),
                OnboardingBullet(systemImage: "doc.on.doc", text: "Bit-identical duplicates via SHA-256"),
            ]
        ),
        OnboardingCard(
            kicker: "System",
            title: "Apps, memory & startup",
            subtitle: "Take real control of what's installed and what's running on your machine.",
            systemImage: "cpu.fill",
            tint: Theme.stripeBlue,
            bullets: [
                OnboardingBullet(systemImage: "trash.slash.fill", text: "Uninstaller removes apps AND their leftover support files"),
                OnboardingBullet(systemImage: "memorychip.fill", text: "Live memory pressure tracker + purge"),
                OnboardingBullet(systemImage: "power", text: "Login items: see what slows your boot, kill it"),
            ]
        ),
        OnboardingCard(
            kicker: "Privacy & Disk",
            title: "Wipe traces, see your disk",
            subtitle: "Clear what shouldn't stick around. Visualize where every byte is going.",
            systemImage: "eye.slash.fill",
            tint: Theme.stripePurple,
            bullets: [
                OnboardingBullet(systemImage: "doc.text.magnifyingglass", text: "Recent files, QuickLook thumbnails, mail downloads"),
                OnboardingBullet(systemImage: "chart.pie.fill", text: "Disk Explorer: sunburst view of what's hogging space"),
                OnboardingBullet(systemImage: "square.and.arrow.down.fill", text: "Drop a folder on the Dock icon to scan it"),
            ]
        ),
        OnboardingCard(
            kicker: "Power user",
            title: "Built for nerds",
            subtitle: "The extras that make MacBroom feel yours. None of it is mandatory — all of it slaps.",
            systemImage: "terminal.fill",
            tint: Color(red: 0.20, green: 0.95, blue: 0.35),
            bullets: [
                OnboardingBullet(systemImage: "ellipsis.curlybraces", text: "Hacker Mode: green-on-black terminal aesthetic"),
                OnboardingBullet(systemImage: "menubar.rectangle", text: "Menu bar widget: quick scan + free space at a glance"),
                OnboardingBullet(systemImage: "command", text: "⌘K command palette — jump anywhere instantly"),
                OnboardingBullet(systemImage: "calendar.badge.clock", text: "Schedule weekly Smart Scans + low-disk alerts"),
            ]
        ),
        OnboardingCard(
            kicker: "Ready?",
            title: "Let's sweep",
            subtitle: "Click the apple on Home. That's the only thing you need to know. The rest you'll discover by playing around.",
            systemImage: "checkmark.seal.fill",
            tint: Theme.stripeOrange,
            bullets: [
                OnboardingBullet(systemImage: "hand.point.up.left.fill", text: "Tap the apple → Smart Scan"),
                OnboardingBullet(systemImage: "trash.fill", text: "Tap again → cleanup"),
                OnboardingBullet(systemImage: "party.popper.fill", text: "Sit back and watch him work"),
            ]
        ),
    ]

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 0)

                topBadge

                AppIconView(size: 96)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.16), radius: 16, y: 10)

                card

                pageIndicator

                actions

                Spacer(minLength: 0)
            }
            .padding(36)
            .frame(maxWidth: 600)
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.96, blue: 0.91),
                         Color(red: 0.96, green: 0.89, blue: 0.79)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Subtle rainbow band on top, à la classic Apple
            VStack {
                LinearGradient(colors: Theme.rainbow,
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 4)
                    .opacity(0.85)
                Spacer()
            }
        }
    }

    private var topBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "wind")
                .font(.system(size: 10, weight: .bold))
            Text("MACBROOM TOUR")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .kerning(1.2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(LinearGradient.rainbow))
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }

    private var card: some View {
        let current = cards[index]
        return VStack(spacing: 14) {
            if let kicker = current.kicker {
                Text(kicker.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .kerning(1.5)
                    .foregroundStyle(current.tint)
            }
            HStack(spacing: 8) {
                Image(systemName: current.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(current.tint)
                Text(current.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.13, green: 0.09, blue: 0.05))
            }
            Text(current.subtitle)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(red: 0.40, green: 0.35, blue: 0.30))
                .frame(maxWidth: 440)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(current.bullets) { bullet in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: bullet.systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(current.tint)
                            .frame(width: 18)
                        Text(bullet.text)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color(red: 0.20, green: 0.16, blue: 0.12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 22).padding(.vertical, 14)
            .frame(maxWidth: 460, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(current.tint.opacity(0.30), lineWidth: 1)
            )
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: direction > 0 ? .trailing : .leading)),
            removal: .opacity.combined(with: .move(edge: direction > 0 ? .leading : .trailing))
        ))
        .id(current.id)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(cards.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? cards[index].tint : Color.black.opacity(0.14))
                    .frame(width: i == index ? 16 : 7, height: 7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: index)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("Skip") { onComplete() }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.black.opacity(0.55))

            Spacer()

            if index > 0 {
                Button("Back") {
                    direction = -1
                    withAnimation(.easeInOut(duration: 0.28)) { index -= 1 }
                }
                .buttonStyle(.bordered)
            }

            if index < cards.count - 1 {
                Button("Next") {
                    direction = 1
                    withAnimation(.easeInOut(duration: 0.28)) { index += 1 }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                RainbowButton("Let's sweep", systemImage: "sparkles") {
                    onComplete()
                }
            }
        }
    }
}
