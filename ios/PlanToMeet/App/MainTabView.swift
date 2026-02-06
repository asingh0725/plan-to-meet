import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Polls", systemImage: "list.bullet.clipboard")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(Theme.accentBlue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState.shared)
        .preferredColorScheme(.dark)
}
