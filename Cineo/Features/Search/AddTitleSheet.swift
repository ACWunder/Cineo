import SwiftUI

struct AddTitleSheet: View {

    let result: TMDBSearchMultiResult

    @Environment(LibraryRepository.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .choose
    @State private var rating: Int = 0
    @State private var isWorking: Bool = false
    @State private var errorMessage: String?

    private enum Step { case choose, rate }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                header
                Spacer(minLength: 0)
                switch step {
                case .choose: chooseSection
                case .rate: rateSection
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Colors.danger)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PosterView(path: result.posterPath, size: "w342", radius: Theme.Radius.md)
                .frame(width: 96)
            Text(result.displayTitle)
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            HStack(spacing: Theme.Spacing.xs) {
                if let mt = result.resolvedMediaType {
                    Label(mt.displayName, systemImage: mt.symbol)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                if !result.year.isEmpty {
                    Text("·").foregroundStyle(Theme.Colors.textTertiary)
                    Text(result.year)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private var chooseSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PrimaryButton(title: "Schon gesehen — bewerten", symbol: "star.fill", kind: .accent) {
                step = .rate
            }
            PrimaryButton(title: "Nur merken (Watchlist)", symbol: "bookmark", kind: .neutral) {
                Task { await save(asWatched: false, rating: nil) }
            }
            .disabled(isWorking)
        }
    }

    private var rateSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("Wie viele Sterne?")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.textPrimary)
            StarRatingView(rating: $rating, size: 40)
            PrimaryButton(title: "Speichern", symbol: "checkmark", kind: .accent) {
                guard rating > 0 else { return }
                Task { await save(asWatched: true, rating: rating) }
            }
            .disabled(rating == 0 || isWorking)
            Button("Zurück") { step = .choose }
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func save(asWatched: Bool, rating: Int?) async {
        guard let mt = result.resolvedMediaType else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let resolvedGenres: [String]
            let overview: String
            let posterPath: String?
            let year: String
            let title: String

            switch mt {
            case .movie:
                let details = try await TMDBClient.shared.movieDetails(result.id)
                resolvedGenres = details.genres.map(\.name)
                overview = details.overview ?? result.overview ?? ""
                posterPath = details.posterPath ?? result.posterPath
                year = details.year.isEmpty ? result.year : details.year
                title = details.title
            case .tv:
                let details = try await TMDBClient.shared.tvDetails(result.id)
                resolvedGenres = details.genres.map(\.name)
                overview = details.overview ?? result.overview ?? ""
                posterPath = details.posterPath ?? result.posterPath
                year = details.year.isEmpty ? result.year : details.year
                title = details.name
            }

            let item = LibraryItem(
                tmdbId: result.id,
                mediaType: mt,
                title: title,
                overview: overview,
                year: year,
                posterPath: posterPath,
                genres: resolvedGenres,
                rating: rating,
                watched: asWatched,
                addedAt: Date()
            )
            await library.add(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
