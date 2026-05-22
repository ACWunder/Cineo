import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DiscoverView()
                .tabItem { Label("Empfehlungen", systemImage: "sparkles") }

            LibraryView()
                .tabItem { Label("Bibliothek", systemImage: "books.vertical.fill") }

            SearchView()
                .tabItem { Label("Suche", systemImage: "magnifyingglass") }

            SeasonsView()
                .tabItem { Label("Staffeln", systemImage: "calendar.badge.clock") }
        }
        .tint(Theme.Colors.accent)
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}
