import SwiftUI

struct SmartScanCard: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("macbroom.hackerMode") private var hackerMode: Bool = false
    @StateObject private var coordinator = SmartScanCoordinator()

    private var stripes: [Color] {
        hackerMode ? Theme.hackerStripes : Theme.rainbow
    }
    private var stripesGradient: LinearGradient {
        hackerMode ? LinearGradient.hackerStripes : LinearGradient.rainbow
    }

    var body: some View {
        VStack(spacing: 12) {
            MacBroomCharacter(
                size: 92,
                phase: characterPhase,
                onTap: triggerPrimaryAction
            )
            statusBlock
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(stripesGradient, lineWidth: 1)
                .opacity(0.55)
        )
    }

    // MARK: - Phase bridging

    private var characterPhase: CharacterPhase {
        switch coordinator.phase {
        case .idle:                       return .idle
        case .scanning:                   return .scanning
        case .ready(let bytes, _):        return .ready(bytes: bytes)
        case .cleaning:                   return .cleaning
        case .done(let bytes):            return .done(reclaimed: bytes)
        }
    }

    // MARK: - Status text under the apple

    private var statusBlock: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(titleStyle)

            Text(statusText)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 32, alignment: .top)
                .padding(.horizontal, 20)

            if case .done = coordinator.phase {
                Button("Run another scan") {
                    Task { await coordinator.scan() }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
        }
    }

    private var title: String {
        switch coordinator.phase {
        case .idle:        return "Smart Scan"
        case .scanning:    return "Scanning…"
        case .ready:       return "Reclaimable"
        case .cleaning:    return "Cleaning…"
        case .done:        return "All clean"
        }
    }

    private var titleStyle: AnyShapeStyle {
        switch coordinator.phase {
        case .ready(let bytes, _) where bytes > 0:
            return AnyShapeStyle(stripesGradient)
        case .done(let bytes) where bytes > 0:
            return AnyShapeStyle(Theme.stripeGreen)
        default:
            return AnyShapeStyle(.primary)
        }
    }

    private var statusText: String {
        switch coordinator.phase {
        case .idle:
            return "Tap the apple to sweep caches and developer junk in parallel."
        case .scanning:
            return "Sweeping caches, logs, dev artifacts and package caches…"
        case .ready(let bytes, let count):
            return "\(FileSystemUtils.formatBytes(bytes)) found in \(count) items — tap the apple to clean."
        case .cleaning:
            return "Moving everything to the Trash. Restore from there if you panic."
        case .done(let bytes):
            return bytes > 0
                ? "Reclaimed \(FileSystemUtils.formatBytes(bytes)). Tap the apple to scan again."
                : "Nothing to reclaim right now. Tap the apple anytime."
        }
    }

    // MARK: - Background

    private var cardBackground: some View {
        ZStack {
            Theme.cardBackground
            LinearGradient(colors: stripes,
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .opacity(0.06)
        }
    }

    // MARK: - Action

    private func triggerPrimaryAction() {
        switch coordinator.phase {
        case .idle, .done:
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
}
