import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DiscoverView()
                .tabItem { Label("Entdecken", systemImage: "sparkles") }

            WatchlistView()
                .tabItem { Label("Watchlist", systemImage: "bookmark.fill") }

            LibraryView()
                .tabItem { Label("Bibliothek", systemImage: "books.vertical.fill") }

            SeasonsView()
                .tabItem { Label("Demnächst", systemImage: "calendar.badge.clock") }
        }
        .tint(Theme.Colors.accent)
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}
