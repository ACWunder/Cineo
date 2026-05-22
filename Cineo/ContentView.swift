import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            switch auth.state {
            case .loading:
                LoadingStateView(message: "Cineo wird vorbereitet …")
            case .signedOut:
                AuthGateView()
            case .signedIn:
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.Colors.accent)
    }
}
