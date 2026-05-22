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
        .task {
            // First-launch warm-up: avoid the ~200ms haptic-engine cold start
            // and the ~2-3s keyboard-subsystem cold start the user would
            // otherwise hit on the first swipe / first search tap.
            HapticEngine.shared.prepare()
            KeyboardWarmer.warm()
        }
    }
}
