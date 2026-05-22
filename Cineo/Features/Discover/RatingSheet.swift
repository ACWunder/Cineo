import SwiftUI

struct RatingSheet: View {
    let title: String
    @Binding var rating: Int
    var onSave: (Int) -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: 0)
                Text("Wie war \(title)?")
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)

                StarRatingView(rating: $rating, size: 46)
                    .padding(.vertical, Theme.Spacing.md)

                PrimaryButton(title: "Speichern", symbol: "checkmark", kind: .accent) {
                    onSave(rating)
                }
                .disabled(rating == 0)
                .padding(.horizontal, Theme.Spacing.lg)

                Button("Abbrechen", action: onCancel)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.bottom, Theme.Spacing.md)
                Spacer(minLength: 0)
            }
        }
    }
}
