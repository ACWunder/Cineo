import SwiftUI

struct PosterView: View {
    let path: String?
    var size: String = "w500"
    var radius: CGFloat = Theme.Radius.md
    var shadow: Bool = true

    @State private var loaded: Bool = false
    /// Bumped on every failure to force AsyncImage to rebuild with a
    /// fresh request. Caps at `maxRetries`; after that we give up and
    /// show the exclamation-mark placeholder.
    @State private var retryCount: Int = 0
    private let maxRetries: Int = 3

    var body: some View {
        let url = TMDB.posterURL(path, size: size)
        ZStack {
            placeholder
            AsyncImage(
                url: url,
                transaction: Transaction(animation: .easeOut(duration: 0.35))
            ) { phase in
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
                    if retryCount < maxRetries {
                        // Transient hiccup — wait briefly and try again.
                        // Delays back off 0.5s → 1s → 2s so a flaky CDN
                        // gets multiple chances without hammering it.
                        Color.clear
                            .task {
                                let delay = 0.5 * pow(2.0, Double(retryCount))
                                try? await Task.sleep(for: .seconds(delay))
                                if !Task.isCancelled {
                                    retryCount += 1
                                }
                            }
                    } else {
                        placeholder.overlay(
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(Theme.Colors.textTertiary)
                        )
                    }
                @unknown default:
                    Color.clear
                }
            }
            // Combining the URL string and the retry counter gives every
            // attempt a unique identity, so SwiftUI tears the previous
            // AsyncImage down and starts a fresh request instead of
            // sitting on a cached failure.
            .id("\(url?.absoluteString ?? "nil")-\(retryCount)")
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
        .onChange(of: path) { _, _ in
            // Cell may have been recycled in a Lazy grid. Reset the
            // retry counter and the fade-in flag so the new poster
            // gets its full retry budget and animates in cleanly.
            retryCount = 0
            loaded = false
        }
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
