import Foundation
#if canImport(UIKit)
import UIKit

/// Single shared haptic engine. Pre-creates and keeps the impact
/// generators warm so the very first haptic event doesn't pay the
/// ~200ms haptic-engine cold-start cost — the cause of the "first
/// swipe ruckelt" symptom.
@MainActor
final class HapticEngine {

    static let shared = HapticEngine()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)

    private init() {
        prepare()
    }

    /// Asks iOS to spin up the haptic engine so the next impact is instant.
    /// Cheap to call multiple times.
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        softImpact.prepare()
    }

    func edge() {
        // Re-prepare *before* the impact too: if the engine slept since the
        // last call (more than a few seconds idle), the previous post-impact
        // prepare() has worn off.
        lightImpact.prepare()
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    func confirm() {
        mediumImpact.prepare()
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    func soft() {
        softImpact.prepare()
        softImpact.impactOccurred()
        softImpact.prepare()
    }
}
#else
@MainActor
final class HapticEngine {
    static let shared = HapticEngine()
    private init() {}
    func prepare() {}
    func edge() {}
    func confirm() {}
    func soft() {}
}
#endif
