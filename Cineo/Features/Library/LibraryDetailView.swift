import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LibraryDetailView: View {
    let item: LibraryItem

    @Environment(LibraryRepository.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var showDeleteConfirm: Bool = false
    @State private var showRatingOverlay: Bool = false
    @State private var extras: DetailExtras?

    private var isInLibrary: Bool { library.contains(tmdbId: item.tmdbId) }

    /// Resolves the live watched-state from the repository so toggles reflect
    /// across edits without re-pushing the view.
    private var liveWatched: Bool {
        library.items.first(where: { $0.tmdbId == item.tmdbId })?.watched ?? item.watched
    }

    /// Three modes drive the buttons + the destructive-alert wording:
    /// - .discover: the item isn't in the library yet (came from Discover detail)
    /// - .watchlist: in the library but not yet watched
    /// - .library: in the library and watched (with or without rating)
    private enum Mode { case discover, watchlist, library }

    private var mode: Mode {
        guard isInLibrary else { return .discover }
        return liveWatched ? .library : .watchlist
    }

    var body: some View {
        ZStack {
            backdrop
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    cover
                    titleBlock
                    if !item.genres.isEmpty { genrePills }
                    if isInLibrary { ratingRow }
                    if !item.overview.isEmpty { description }
                    castRow
                    actions
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)
            }

            if showRatingOverlay {
                RatingOverlay(
                    title: item.title,
                    posterPath: item.posterPath,
                    onRate: { commitRating($0) },
                    onSkip: { commitRating(nil) },
                    onCancel: { showRatingOverlay = false }
                )
                .zIndex(99)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { rating = item.rating ?? 0 }
        .task(id: item.tmdbId) {
            extras = await TMDBClient.shared.extras(for: item.tmdbId, mediaType: item.mediaType)
        }
        .alert(removeAlertTitle, isPresented: $showDeleteConfirm) {
            Button("Entfernen", role: .destructive) {
                Task {
                    await library.remove(tmdbId: item.tmdbId)
                    dismiss()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Du kannst „\(item.title)“ später wieder hinzufügen.")
        }
    }

    private var removeAlertTitle: String {
        switch mode {
        case .watchlist: "Aus Watchlist entfernen?"
        default: "Aus Bibliothek entfernen?"
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            Theme.Colors.background

            // Prefer the wide backdrop (cinematic), fall back to a blurred
            // poster when TMDB has none.
            if let backdropURL = TMDB.backdropURL(extras?.backdropPath, size: "w1280") {
                AsyncImage(url: backdropURL, transaction: Transaction(animation: .easeOut(duration: 0.35))) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 30)
                .opacity(0.55)
                .ignoresSafeArea()
            } else if TMDB.posterURL(item.posterPath, size: "w780") != nil {
                PosterView(path: item.posterPath, size: "w780", radius: 0, shadow: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaledToFill()
                    .blur(radius: 70)
                    .opacity(0.35)
                    .ignoresSafeArea()
            }
            LinearGradient(
                stops: [
                    .init(color: Theme.Colors.background.opacity(0.35), location: 0.0),
                    .init(color: Theme.Colors.background.opacity(0.85), location: 0.45),
                    .init(color: Theme.Colors.background, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Cover + title

    private var cover: some View {
        ZStack(alignment: .bottomTrailing) {
            PosterView(path: item.posterPath, size: "w780", radius: Theme.Radius.lg)
                .frame(maxWidth: 220)
                .shadow(color: Theme.Colors.shadow, radius: 38, y: 22)
                .shadow(color: Theme.Colors.accentGlow.opacity(0.25), radius: 70, y: 0)

            if let key = extras?.trailerYouTubeKey {
                Button {
                    openTrailer(key: key)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0x2A1A05))
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.accentGradient, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 0.6))
                        .shadow(color: Theme.Colors.accentGlow, radius: 18, y: 6)
                }
                .buttonStyle(CineoPressStyle(scale: 0.9))
                .padding(10)
                .accessibilityLabel("Trailer abspielen")
            }
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private func openTrailer(key: String) {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(key)") else { return }
#if canImport(UIKit)
        UIApplication.shared.open(url)
#endif
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(item.title)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.55), radius: 10, y: 3)
                .minimumScaleFactor(0.85)

            HStack(spacing: 6) {
                Image(systemName: item.mediaType.symbol)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                Text(item.mediaType.displayName)
                if !item.year.isEmpty {
                    Text("·").foregroundStyle(Theme.Colors.textTertiary)
                    Text(item.year)
                }
                if let runtime = extras?.runtimeMinutes, runtime > 0 {
                    Text("·").foregroundStyle(Theme.Colors.textTertiary)
                    Text("\(runtime) min")
                }
            }
            .font(Theme.Typography.footnote)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Genres

    private var genrePills: some View {
        CenteredFlow(spacing: 6, lineSpacing: 6) {
            ForEach(item.genres, id: \.self) { g in
                Text(g.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(Theme.Colors.accentLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial.opacity(0.5), in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(Theme.Colors.accent.opacity(0.3), lineWidth: 0.7)
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Cast

    @ViewBuilder
    private var castRow: some View {
        if let cast = extras?.cast, !cast.isEmpty {
            // Centered, no horizontal scroll, no overflow — limit to four so
            // the row fits the screen width on every device.
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                ForEach(Array(cast.prefix(4))) { member in
                    CastChip(member: member)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Rating

    private var ratingRow: some View {
        StarRatingView(rating: $rating, size: 30)
            .onChange(of: rating) { _, newValue in
                Task {
                    await library.updateRating(tmdbId: item.tmdbId, rating: newValue > 0 ? newValue : nil)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - Description

    private var description: some View {
        Text(item.overview)
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.textPrimary.opacity(0.88))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.top, Theme.Spacing.xs)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch mode {
        case .library:
            actionPill(
                symbol: "trash",
                label: "Aus Bibliothek entfernen",
                kind: .danger
            ) {
                showDeleteConfirm = true
            }
            .padding(.top, Theme.Spacing.sm)
        case .watchlist:
            HStack(spacing: Theme.Spacing.sm) {
                actionPill(symbol: "eye.fill", label: "Gesehen", kind: .accent) {
                    showRatingOverlay = true
                }
                actionPill(symbol: "trash", label: "Aus Watchlist", kind: .danger) {
                    showDeleteConfirm = true
                }
            }
            .padding(.top, Theme.Spacing.sm)
        case .discover:
            HStack(spacing: Theme.Spacing.sm) {
                actionPill(symbol: "star.fill", label: "Bewerten", kind: .accent) {
                    showRatingOverlay = true
                }
                actionPill(symbol: "bookmark", label: "Watchlist", kind: .neutral) {
                    Task {
                        let watchlistItem = LibraryItem(
                            tmdbId: item.tmdbId,
                            mediaType: item.mediaType,
                            title: item.title,
                            overview: item.overview,
                            year: item.year,
                            posterPath: item.posterPath,
                            genres: item.genres,
                            rating: nil,
                            watched: false,
                            addedAt: Date()
                        )
                        await library.add(watchlistItem)
                        dismiss()
                    }
                }
            }
            .padding(.top, Theme.Spacing.sm)
        }
    }

    private enum PillKind { case accent, neutral, danger }

    private func actionPill(symbol: String,
                            label: String,
                            kind: PillKind,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(pillForeground(kind))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(pillBackground(kind))
            .overlay(
                Capsule().stroke(pillBorder(kind), lineWidth: 0.6)
            )
            .clipShape(Capsule())
            .shadow(color: pillGlow(kind), radius: 14, y: 6)
        }
        .buttonStyle(CineoPressStyle(scale: 0.93))
    }

    private func pillForeground(_ kind: PillKind) -> Color {
        switch kind {
        case .accent: Color(hex: 0x2A1A05)
        case .neutral: Theme.Colors.textPrimary
        case .danger: Theme.Colors.textPrimary
        }
    }

    @ViewBuilder
    private func pillBackground(_ kind: PillKind) -> some View {
        switch kind {
        case .accent:
            ZStack {
                Capsule().fill(Theme.Colors.accentGradient)
                Capsule().fill(Theme.Colors.accentSheen).blendMode(.plusLighter)
            }
        case .neutral:
            Capsule().fill(.ultraThinMaterial.opacity(0.5))
        case .danger:
            Capsule().fill(Theme.Colors.danger.opacity(0.75))
        }
    }

    private func pillBorder(_ kind: PillKind) -> Color {
        switch kind {
        case .accent: Color.white.opacity(0.22)
        case .neutral: Theme.Colors.border
        case .danger: Color.white.opacity(0.12)
        }
    }

    private func pillGlow(_ kind: PillKind) -> Color {
        switch kind {
        case .accent: Theme.Colors.accentGlow.opacity(0.55)
        case .danger: Theme.Colors.danger.opacity(0.35)
        case .neutral: .clear
        }
    }

    // MARK: - Discover-rating commit

    /// Both the discover-rating and the watchlist-promote-to-library paths
    /// land here. The first writes a fresh LibraryItem with watched=true,
    /// the second flips the existing item to watched and applies the rating.
    private func commitRating(_ value: Int?) {
        withAnimation(.easeOut(duration: 0.25)) {
            showRatingOverlay = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dismiss()
        }
        switch mode {
        case .watchlist:
            Task { await library.markWatched(tmdbId: item.tmdbId, rating: value) }
        case .discover, .library:
            // .library shouldn't reach here (no rating overlay trigger), but
            // we still add as a safety net.
            let watched = LibraryItem(
                tmdbId: item.tmdbId,
                mediaType: item.mediaType,
                title: item.title,
                overview: item.overview,
                year: item.year,
                posterPath: item.posterPath,
                genres: item.genres,
                rating: value,
                watched: true,
                addedAt: Date()
            )
            Task { await library.add(watched) }
        }
    }
}

// Flow layout that centers each row horizontally.
struct CenteredFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(into: CGFloat(0)) { acc, row in
            acc += row.height
            acc += lineSpacing
        } - (rows.isEmpty ? 0 : lineSpacing)
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowWidth = row.width
            var x = bounds.minX + (bounds.width - rowWidth) / 2  // center
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = current.width + (current.indices.isEmpty ? 0 : spacing) + size.width
            if projected > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            if !current.indices.isEmpty { current.width += spacing }
            current.indices.append(index)
            current.width += size.width
            current.height = max(current.height, size.height)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// Lightweight flow layout for tag chips (no third-party deps).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        var totalH: CGFloat = 0
        var maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                totalH += rowH + spacing
                y += rowH + spacing
                x = 0
                rowH = 0
            }
            x += size.width + spacing
            rowH = max(rowH, size.height)
            maxX = max(maxX, x)
        }
        totalH += rowH
        return CGSize(width: maxX, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0
        let maxX = bounds.maxX
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxX, x > bounds.minX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

// MARK: - Provider icon

private struct ProviderIcon: View {
    let provider: DetailExtras.Provider

    var body: some View {
        AsyncImage(url: TMDB.providerLogoURL(provider.logoPath, size: "w92")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                placeholder
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
        .accessibilityLabel(provider.name)
    }

    private var placeholder: some View {
        Theme.Colors.surfaceElevated
            .overlay(
                Text(provider.name.prefix(1).uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            )
    }
}

// MARK: - Cast chip

private struct CastChip: View {
    let member: DetailExtras.CastMember

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: TMDB.profileURL(member.profilePath, size: "w185")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Theme.Colors.surfaceElevated.overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Theme.Colors.textTertiary)
                    )
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            Text(member.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if let character = member.character, !character.isEmpty {
                Text(character)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
