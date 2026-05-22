import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth

@MainActor
@Observable
final class AuthService: NSObject {

    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(uid: String)

        var uid: String? {
            if case .signedIn(let uid) = self { return uid }
            return nil
        }
    }

    private(set) var state: State = .loading
    private(set) var lastError: String?

    private var currentNonce: String?
    private var continuation: CheckedContinuation<Void, Error>?
    nonisolated(unsafe) private var authHandle: AuthStateDidChangeListenerHandle?

    override init() {
        super.init()
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                if let user {
                    self.state = .signedIn(uid: user.uid)
                } else {
                    self.state = .signedOut
                }
            }
        }
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Sign in with Apple

    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let err):
            lastError = err.localizedDescription
        case .success(let auth):
            await completeFirebaseSignIn(with: auth)
        }
    }

    private func completeFirebaseSignIn(with auth: ASAuthorization) async {
        guard
            let credential = auth.credential as? ASAuthorizationAppleIDCredential,
            let nonce = currentNonce,
            let tokenData = credential.identityToken,
            let tokenString = String(data: tokenData, encoding: .utf8)
        else {
            lastError = "Apple-Anmeldung lieferte kein gültiges Token."
            return
        }

        let firCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        do {
            _ = try await Auth.auth().signIn(with: firCredential)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if random < charset.count {
                result.append(charset[Int(random) % charset.count])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
