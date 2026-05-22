import SwiftUI

struct LibraryDetailView: View {
    let item: LibraryItem

    @Environment(LibraryRepository.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var showDeleteConfirm: Bool = false
    @State private var isSaving: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                hero
                ratingBox
                genreChips
                descriptionBox
                actions
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
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

    private var hero: some View {
        VStack(spacing: Theme.Spacing.md) {
            PosterView(path: item.posterPath, size: "w780", radius: Theme.Radius.lg)
                .frame(maxWidth: 300)
                .padding(.top, Theme.Spacing.sm)
            VStack(spacing: 4) {
                Text(item.title)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                HStack(spacing: Theme.Spacing.xs) {
                    Label(item.mediaType.displayName, systemImage: item.mediaType.symbol)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if !item.year.isEmpty {
                        Text("·").foregroundStyle(Theme.Colors.textTertiary)
                        Text(item.year)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    private var ratingBox: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(rating == 0 ? "Noch nicht bewertet" : "Deine Bewertung")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            StarRatingView(rating: $rating, size: 38)
                .onChange(of: rating) { _, newValue in
                    Task {
                        isSaving = true
                        await library.updateRating(tmdbId: item.tmdbId, rating: newValue > 0 ? newValue : nil)
                        isSaving = false
                    }
                }
            if isSaving {
                Text("Speichere …")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .cineoCard()
    }

    @ViewBuilder
    private var genreChips: some View {
        if !item.genres.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Genres")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                FlowLayout(spacing: Theme.Spacing.xs) {
                    ForEach(item.genres, id: \.self) { g in
                        Text(g)
                            .font(Theme.Typography.footnote)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.surfaceElevated, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.Colors.border, lineWidth: 0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cineoCard()
        }
    }

    @ViewBuilder
    private var descriptionBox: some View {
        if !item.overview.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Beschreibung")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text(item.overview)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cineoCard()
        }
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PrimaryButton(
                title: item.watched ? "Als ungesehen markieren" : "Als gesehen markieren",
                symbol: item.watched ? "eye.slash" : "eye",
                kind: .neutral
            ) {
                Task { await library.setWatched(tmdbId: item.tmdbId, watched: !item.watched) }
            }
            PrimaryButton(title: "Aus Bibliothek entfernen", symbol: "trash", kind: .danger) {
                showDeleteConfirm = true
            }
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
