import SwiftUI
import AuthenticationServices

struct AuthGateView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Theme.Colors.accent)
                    .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 24)

                Text("Cineo")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .tracking(0.5)

                Text("Dein schlanker Film- und Serien-Tracker.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                auth.handleAppleRequest(request)
            } onCompletion: { result in
                Task { await auth.handleAppleResult(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: Theme.Layout.buttonHeight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .padding(.horizontal, Theme.Spacing.lg)

            if let error = auth.lastError {
                Text(error)
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(Theme.Colors.danger)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .multilineTextAlignment(.center)
            }

            Text("Wir nutzen Apple-Anmeldung, um deine Bibliothek geräteübergreifend zu synchronisieren.")
                .font(Theme.Typography.footnote)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
        }
        .cineoBackground()
    }
}
