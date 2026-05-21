import SwiftUI

struct MaintenanceView: View {
    @State private var running: String?
    @State private var lastResult: (id: String, success: Bool, message: String)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHero(
                item: .maintenance,
                subtitle: "System fixes & cleanup recipes that usually live in OnyX, now one-click here."
            )

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                    ForEach(MaintenanceCatalog.all) { action in
                        ActionCard(
                            action: action,
                            isRunning: running == action.id,
                            result: lastResult?.id == action.id ? lastResult : nil
                        ) {
                            Task { await runAction(action) }
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    private func runAction(_ action: MaintenanceAction) async {
        running = action.id
        defer { running = nil }
        let result = await ShellRunner.run(action.command, requiresAdmin: action.requiresAdmin)
        lastResult = (
            id: action.id,
            success: result.success,
            message: result.success
                ? "Done"
                : (result.errorMessage ?? "Failed")
        )
    }
}

private struct ActionCard: View {
    let action: MaintenanceAction
    let isRunning: Bool
    let result: (id: String, success: Bool, message: String)?
    let onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(SidebarItem.maintenance.tint.opacity(0.20))
                        .frame(width: 34, height: 34)
                    Image(systemName: action.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SidebarItem.maintenance.tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(action.title)
                            .font(.system(size: 13, weight: .semibold))
                        if action.requiresAdmin {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .help("Requires admin password")
                        }
                    }
                    if let result {
                        HStack(spacing: 4) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(result.success ? Theme.stripeGreen : Theme.stripeRed)
                            Text(result.message)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
            Text(action.blurb)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
            HStack {
                Spacer()
                Button(action: onRun) {
                    if isRunning {
                        SweepingBroomLoader(size: 18)
                    } else {
                        Label("Run", systemImage: "play.fill")
                    }
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(SidebarItem.maintenance.tint)
                .disabled(isRunning)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
