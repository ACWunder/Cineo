import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var size: CGFloat = 44
    var isInteractive: Bool = true

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    guard isInteractive else { return }
                    if rating == value {
                        rating = 0
                    } else {
                        rating = value
                    }
                } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.system(size: size, weight: .semibold))
                        .foregroundStyle(value <= rating ? Theme.Colors.starFilled : Theme.Colors.starEmpty)
                        .contentShape(Rectangle())
                        .frame(width: size + 12, height: size + 12)
                }
                .buttonStyle(.plain)
                .disabled(!isInteractive)
            }
        }
    }
}

struct StarRatingDisplay: View {
    let rating: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(value <= rating ? Theme.Colors.starFilled : Theme.Colors.starEmpty)
            }
        }
    }
}
