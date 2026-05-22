import SwiftUI

struct LibraryDetailView: View {
    let item: LibraryItem

    @Environment(LibraryRepository.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var showDeleteConfirm: Bool = false
    @State private var showRatingOverlay: Bool = false

    private var isInLibrary: Bool { library.contains(tmdbId: item.tmdbId) }

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
                    actions
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)
            }

            if showRatingOverlay {
                RatingOverlay(
                    title: item.title,
                    posterPath: item.posterPath,
                    onRate: { saveDiscoverRating($0) },
                    onSkip: { saveDiscoverRating(nil) },
                    onCancel: { showRatingOverlay = false }
                )
                .zIndex(99)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { rating = item.rating ?? 0 }
        .alert("Aus Bibliothek entfernen?", isPresented: $showDeleteConfirm) {
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

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            Theme.Colors.background
            if TMDB.posterURL(item.posterPath, size: "w780") != nil {
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
        PosterView(path: item.posterPath, size: "w780", radius: Theme.Radius.lg)
            .frame(maxWidth: 220)
            .shadow(color: Theme.Colors.shadow, radius: 38, y: 22)
            .shadow(color: Theme.Colors.accentGlow.opacity(0.25), radius: 70, y: 0)
            .padding(.top, Theme.Spacing.xs)
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
            }
            .font(Theme.Typography.footnote)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Genres

    private var genrePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
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
            .padding(.horizontal, Theme.Spacing.sm)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -Theme.Spacing.sm)
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
        if isInLibrary {
            HStack(spacing: Theme.Spacing.sm) {
                actionPill(
                    symbol: item.watched ? "eye.slash" : "eye.fill",
                    label: item.watched ? "Ungesehen" : "Gesehen",
                    kind: .neutral
                ) {
                    Task { await library.setWatched(tmdbId: item.tmdbId, watched: !item.watched) }
                }
                actionPill(
                    symbol: "trash",
                    label: "Entfernen",
                    kind: .danger
                ) {
                    showDeleteConfirm = true
                }
            }
            .padding(.top, Theme.Spacing.sm)
        } else {
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

    private func saveDiscoverRating(_ value: Int?) {
        Task {
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
            await library.add(watched)
            showRatingOverlay = false
            dismiss()
        }
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
