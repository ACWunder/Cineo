import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Process-wide in-memory cache of decoded poster bitmaps. Keyed by
/// URL string. The Discover departing-card layer (and any list cell
/// that reappears) reads from this and renders on the very first
/// frame — no placeholder, no AsyncImage phase flash.
///
/// Critically, every entry is stored *after* `byPreparingForDisplay`
/// has decoded the JPEG into a ready-to-draw bitmap. The first draw
/// on the main thread no longer has to decompress anything — which
/// is what made the first scroll/filter/search after a fresh build
/// stutter. (URLCache on disk survives an app restart, the in-memory
/// decoded bitmap does not. So "smooth after restart, choppy after
/// rebuild" is exactly this cache being cold for one and warm for
/// the other.)
final class PosterImageCache {
    static let shared = PosterImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 240
    }

    func image(for url: URL?) -> UIImage? {
        guard let url else { return nil }
        return cache.object(forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, for url: URL?) {
        guard let url else { return }
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }

    /// Download, decode and store the poster at `url`. Safe to call
    /// from any actor; returns once the bitmap is fully ready for
    /// display. No-op when the URL is already cached.
    func prefetch(_ url: URL) async {
        if image(for: url) != nil { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let ui = UIImage(data: data) {
                let prepared = await ui.byPreparingForDisplay() ?? ui
                store(prepared, for: url)
            }
        } catch {
            // Silent: the next on-screen PosterView will retry with
            // its own backoff schedule when the user actually looks
            // at this cell.
        }
    }
}

struct PosterView: View {
    let path: String?
    let size: String
    let radius: CGFloat
    let shadow: Bool

    @State private var image: UIImage?
    @State private var loadFailed: Bool = false

    /// Initialise `image` from the shared cache so a poster that was
    /// just visible elsewhere (e.g. a Discover card we're now flying
    /// off-screen) renders without a placeholder on its first frame.
    init(path: String?,
         size: String = "w500",
         radius: CGFloat = Theme.Radius.md,
         shadow: Bool = true) {
        self.path = path
        self.size = size
        self.radius = radius
        self.shadow = shadow
        let url = TMDB.posterURL(path, size: size)
        _image = State(initialValue: PosterImageCache.shared.image(for: url))
    }

    var body: some View {
        let url = TMDB.posterURL(path, size: size)
        ZStack {
            placeholder
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Theme.Colors.textTertiary)
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
        .task(id: url?.absoluteString ?? "") {
            await loadIfNeeded(url: url)
        }
        .onChange(of: path) { _, _ in
            // Recycled cell (LazyVGrid): wipe the failure flag so the
            // new poster gets a fresh attempt. The cache lookup in the
            // `.task` will refill `image` if the new URL is known.
            loadFailed = false
            image = PosterImageCache.shared.image(for: TMDB.posterURL(path, size: size))
        }
    }

    private func loadIfNeeded(url: URL?) async {
        // Already painted (either from the init-time cache hit or a
        // prior load): nothing to do.
        if image != nil { return }
        guard let url else { return }

        // Cache may have been populated by a sibling view between
        // init() and the task firing — double-check.
        if let cached = PosterImageCache.shared.image(for: url) {
            image = cached
            return
        }

        // Backoff schedule: 0s, 0.5s, 1.0s, 2.0s. Total ~3.5s budget
        // before we give up and show the placeholder + warning.
        let delays: [Double] = [0, 0.5, 1.0, 2.0]
        for delay in delays {
            if Task.isCancelled { return }
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            if Task.isCancelled { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if Task.isCancelled { return }
                if let ui = UIImage(data: data) {
                    // Decode the JPEG into a drawable bitmap off the
                    // main thread. Without this, `Image(uiImage:)`'s
                    // first draw forces a synchronous decode on the
                    // main thread — which is what causes scroll/
                    // filter/search to stutter on the very first run
                    // after a fresh build (URLCache is cold, every
                    // poster decodes for the first time).
                    let prepared = await ui.byPreparingForDisplay() ?? ui
                    if Task.isCancelled { return }
                    PosterImageCache.shared.store(prepared, for: url)
                    // No `withAnimation` here — a fade-in from
                    // placeholder to poster reads as a "second"
                    // image briefly overlapping the first. Instant
                    // swap is the right choice for a card stack:
                    // either the poster is already cached (no
                    // visible change at all) or it appears as soon
                    // as the network gives it to us.
                    image = prepared
                    return
                }
            } catch {
                if Task.isCancelled { return }
                // Fall through to retry.
            }
        }
        loadFailed = true
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
