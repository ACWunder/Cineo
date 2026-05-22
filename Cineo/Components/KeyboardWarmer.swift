import Foundation
#if canImport(UIKit)
import UIKit

/// Pre-warms the iOS text input / keyboard subsystem so the first tap on
/// any TextField doesn't trigger the ~2-3 second cold-start lag. Apple
/// loads the keyboard process lazily; touching a UITextField once forces
/// it to spin up early in the background where the user doesn't notice.
@MainActor
enum KeyboardWarmer {
    private static var didWarm = false

    static func warm() {
        guard !didWarm else { return }
        didWarm = true

        // Defer until the first runloop tick so we have a window attached.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let window = Self.activeWindow() else { return }
            let dummy = UITextField(frame: .zero)
            dummy.isHidden = true
            window.addSubview(dummy)
            dummy.becomeFirstResponder()
            DispatchQueue.main.async {
                dummy.resignFirstResponder()
                dummy.removeFromSuperview()
            }
        }
    }

    private static func activeWindow() -> UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if let key = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return key
            }
            if let first = windowScene.windows.first {
                return first
            }
        }
        return nil
    }
}
#else
@MainActor
enum KeyboardWarmer {
    static func warm() {}
}
#endif
