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

            // Pre-render the rating overlay's view tree once invisible so
            // the first real rating doesn't pay SwiftUI's initial layout +
            // compile cost. 1×1, fully transparent, hit-testing off.
            RatingOverlay(
                title: "",
                posterPath: nil,
                onRate: { _ in },
                onSkip: {},
                onCancel: {}
            )
            .frame(width: 1, height: 1)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
