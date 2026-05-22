import SwiftUI

struct PosterView: View {
    let path: String?
    var size: String = "w500"
    var radius: CGFloat = Theme.Radius.md
    var shadow: Bool = true

    @State private var loaded: Bool = false

    var body: some View {
        let url = TMDB.posterURL(path, size: size)
        ZStack {
            placeholder
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.35))) { phase in
                switch phase {
                case .empty:
                    Color.clear
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .opacity(loaded ? 1 : 0)
                        .onAppear { loaded = true }
                case .failure:
                    placeholder.overlay(
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Theme.Colors.textTertiary)
                    )
                @unknown default:
                    Color.clear
                }
            }
        }
        .aspectRatio(Theme.Layout.posterAspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Theme.Colors.border, lineWidth: 0.5)
        )
        .shadow(color: shadow ? Theme.Colors.shadow : .clear,
                radius: shadow ? Theme.Layout.cardShadowRadius : 0,
                x: 0, y: shadow ? 14 : 0)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Colors.surfaceElevated, Theme.Colors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "film.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.Colors.textTertiary.opacity(0.6))
        }
    }
}
