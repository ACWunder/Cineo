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
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    func confirm() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    func soft() {
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
