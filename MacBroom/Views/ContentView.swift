import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("macbroom.hackerMode") private var hackerMode: Bool = false

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $appState.selection) { item in
                Text(item.title).tag(item)
            }
        } detail: {
            detail
        }
    }

    private var sidebar: some View {
        List(SidebarItem.allCases, selection: $appState.selection) { item in
            NavigationLink(value: item) {
                SidebarRow(item: item, isSelected: appState.selection == item)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        .safeAreaInset(edge: .top) {
            BrandHeader()
        }
        .overlay(alignment: .leading) {
            LinearGradient(
                colors: hackerMode ? Theme.hackerStripes : Theme.rainbow,
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 3)
            .opacity(0.85)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch appState.selection ?? .home {
        case .home:        HomeView()
        case .dashboard:   DashboardView()
        case .caches:      CachesView()
        case .devJunk:     DevJunkView()
        case .uninstaller: UninstallerView()
        case .largeFiles:  LargeFilesView()
        case .duplicates:  DuplicatesView()
        case .privacy:     PrivacyView()
        case .mail:        MailDownloadsView()
        case .memory:      MemoryView()
        case .maintenance: MaintenanceView()
        case .explorer:    DiskExplorerView()
        case .startup:     StartupItemsView()
        case .hacker:      HackerView()
        }
    }
}

private struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(item.tint.opacity(isSelected ? 0.30 : 0.18))
                    .frame(width: 24, height: 24)
                Image(systemName: item.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.tint)
            }
            Text(item.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
        }
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("MacBroom")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient.rainbow)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 1100, height: 700)
}
