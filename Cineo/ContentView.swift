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

            // Pre-render heavy view trees once invisible so the first real
            // use doesn't pay SwiftUI's initial layout + compile cost.
            // 1×1, fully transparent, no hit-testing.
            prewarmViews
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

    /// Invisible 1×1 render of the views with the heaviest SwiftUI compile
    /// cost. Without this the user pays the cost on their first interaction
    /// (e.g. tapping a filter chip) — after an app restart these paths are
    /// cached so subsequent runs feel fast. Touching them here at launch
    /// gets the cache warm before the user can ever notice.
    private var prewarmViews: some View {
        VStack(spacing: 0) {
            // Rating overlay — pre-mounts the full-screen rating UI.
            RatingOverlay(
                title: "",
                posterPath: nil,
                onRate: { _ in },
                onSkip: {},
                onCancel: {}
            )
            // A Menu — pre-mounts iOS's menu/popover subsystem so the first
            // filter / sort tap doesn't stutter while UIMenu wakes up.
            Menu {
                Button("warm") {}
            } label: {
                Color.clear
            }
        }
        .frame(width: 1, height: 1)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
