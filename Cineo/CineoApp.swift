import SwiftUI

@main
struct CineoApp: App {

    @State private var auth: AuthService
    @State private var library: LibraryRepository
    @State private var dismissed: DismissedRepository

    init() {
        FirebaseBootstrap.configure()
        _auth = State(initialValue: AuthService())
        _library = State(initialValue: LibraryRepository())
        _dismissed = State(initialValue: DismissedRepository())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .environment(library)
                .environment(dismissed)
                .task(id: auth.state) {
                    switch auth.state {
                    case .signedIn(let uid):
                        library.start(uid: uid)
                        dismissed.start(uid: uid)
                        try? await TMDBClient.shared.ensureGenresLoaded()
                    case .signedOut:
                        library.stop()
                        dismissed.stop()
                    case .loading:
                        break
                    }
                }
        }
    }
}
