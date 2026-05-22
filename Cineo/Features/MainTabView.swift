import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DiscoverView()
                .tabItem { Label("Empfehlungen", systemImage: "sparkles") }

            WatchlistView()
                .tabItem { Label("Watchlist", systemImage: "bookmark.fill") }

            LibraryView()
                .tabItem { Label("Bibliothek", systemImage: "books.vertical.fill") }

            SeasonsView()
                .tabItem { Label("Staffeln", systemImage: "calendar.badge.clock") }
        }
        .tint(Theme.Colors.accentLight)
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}
