import Foundation
import FirebaseCore

enum FirebaseBootstrap {
    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}
