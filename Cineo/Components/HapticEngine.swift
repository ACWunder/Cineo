import Foundation

/// Haptics were intentionally disabled across the app. The shared singleton
/// stays so existing callers (DiscoverView swipe, RatingOverlay commit, etc.)
/// keep compiling, but every method is now a no-op. Restore by uncommenting
/// the UIImpactFeedbackGenerator calls below if you ever want them back.
@MainActor
final class HapticEngine {
    static let shared = HapticEngine()

    private init() {}

    func prepare() {}
    func edge() {}
    func confirm() {}
    func soft() {}
}
