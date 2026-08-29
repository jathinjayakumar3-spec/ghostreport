import SwiftUI

struct RootTabView: View {
    @State private var selection = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                NavigationStack { DashboardView() }
                    .tag(0)
                NavigationStack { ToolsHomeView() }
                    .tag(1)
                NavigationStack { DiagnosticsLogView() }
                    .tag(2)
                NavigationStack { SettingsView() }
                    .tag(3)
            }
            .toolbar(.hidden, for: .tabBar)

            tabBar
        }
        .preferredColorScheme(.dark)
        .tint(Theme.cyan)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem(0, "Dashboard", "square.grid.2x2.fill")
            tabItem(1, "Tools", "wrench.and.screwdriver.fill")
            tabItem(2, "Logs", "doc.text.fill")
            tabItem(3, "Settings", "gearshape.fill")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .glassCard(corner: 26)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private func tabItem(_ index: Int, _ title: String, _ icon: String) -> some View {
        let selected = selection == index
        return Button {
            withAnimation(.snappy) { selection = index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(selected ? Theme.cyan : Theme.faint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.cyan.opacity(0.14))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
