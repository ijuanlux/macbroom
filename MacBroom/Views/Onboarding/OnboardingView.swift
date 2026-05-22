import SwiftUI

struct OnboardingCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
}

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var index: Int = 0

    private let cards: [OnboardingCard] = [
        OnboardingCard(
            title: "Welcome to MacBroom",
            subtitle: "A free, open-source Mac cleaner with personality. Built for the community, no paywall.",
            systemImage: "wind",
            tint: Theme.stripeOrange
        ),
        OnboardingCard(
            title: "Click the apple to clean",
            subtitle: "Smart Scan finds caches and developer junk in one click. The apple icon on the dashboard is the magic button.",
            systemImage: "sparkles",
            tint: Theme.stripeGreen
        ),
        OnboardingCard(
            title: "Cmd+K for everything",
            subtitle: "Open the command palette to jump to any section, toggle Hacker Mode, or run common actions by keyboard.",
            systemImage: "command",
            tint: Theme.stripeBlue
        ),
        OnboardingCard(
            title: "Set it and forget it",
            subtitle: "Settings → Automation lets you schedule weekly Smart Scans and get notified when free space is low.",
            systemImage: "bell.badge",
            tint: Theme.stripePurple
        ),
    ]

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                AppIconView(size: 140)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 22, y: 12)

                card

                pageIndicator

                actions

                Spacer(minLength: 0)
            }
            .padding(40)
            .frame(maxWidth: 520)
        }
    }

    private var background: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.99, green: 0.96, blue: 0.91),
                     Color(red: 0.96, green: 0.89, blue: 0.79)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var card: some View {
        let current = cards[index]
        return VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: current.systemImage)
                    .foregroundStyle(current.tint)
                Text(current.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.15, green: 0.10, blue: 0.06))
            }
            Text(current.subtitle)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(red: 0.40, green: 0.35, blue: 0.30))
                .frame(maxWidth: 420)
                .frame(minHeight: 70, alignment: .top)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .id(current.id)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(cards.indices, id: \.self) { i in
                Circle()
                    .fill(i == index ? Theme.stripeOrange : Color.black.opacity(0.12))
                    .frame(width: 7, height: 7)
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
                    withAnimation(.easeInOut(duration: 0.25)) { index -= 1 }
                }
                .buttonStyle(.bordered)
            }

            if index < cards.count - 1 {
                Button("Next") {
                    withAnimation(.easeInOut(duration: 0.25)) { index += 1 }
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
