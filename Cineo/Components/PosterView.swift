import SwiftUI

struct PosterView: View {
    let path: String?
    var size: String = "w500"
    var radius: CGFloat = Theme.Radius.md
    var shadow: Bool = true

    var body: some View {
        let url = TMDB.posterURL(path, size: size)
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                placeholder
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder.overlay(
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Theme.Colors.textTertiary)
                )
            @unknown default:
                placeholder
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
                x: 0, y: shadow ? 12 : 0)
    }

    private var placeholder: some View {
        ZStack {
            Theme.Colors.surfaceElevated
            Image(systemName: "film")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}
