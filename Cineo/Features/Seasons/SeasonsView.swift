import SwiftUI

struct SeasonsView: View {
    @Environment(LibraryRepository.self) private var library
    @State private var viewModel = SeasonsViewModel()

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                content
            }
        }
        .task(id: library.items.map(\.tmdbId)) {
            await viewModel.reload(library: library.items)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                Task { await viewModel.reload(library: library.items) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.accentLight)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.surfaceElevated, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.Colors.border, lineWidth: 0.5))
            }
            .buttonStyle(CineoPressStyle(scale: 0.92))
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
    }

    @ViewBuilder
    private var content: some View {
        let hasAnySeries = library.items.contains(where: { $0.mediaType == .tv })
        if viewModel.isLoading && viewModel.upcoming.isEmpty && viewModel.dormant.isEmpty {
            LoadingStateView(message: "Hole neue Folgen …")
        } else if !hasAnySeries {
            EmptyStateView(
                symbol: "tv",
                title: "Keine Serien",
                message: "Wenn du Serien hinzufügst, siehst du hier ihre nächsten Folgen."
            )
        } else if viewModel.upcoming.isEmpty && viewModel.dormant.isEmpty {
            EmptyStateView(
                symbol: "calendar.badge.exclamationmark",
                title: "Nichts angekündigt",
                message: "Aktuell ist keine neue Folge bekannt."
            )
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if !viewModel.upcoming.isEmpty {
                    sectionHeader("Demnächst neu")
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.upcoming) { row in
                            SeriesRow(status: row)
                        }
                    }
                }
                if !viewModel.dormant.isEmpty {
                    sectionHeader("Keine neue Staffel angekündigt")
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.dormant) { row in
                            SeriesRow(status: row)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.title3)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SeriesRow: View {
    let status: SeasonsViewModel.SeriesStatus

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            PosterView(path: status.item.posterPath, size: "w342", radius: Theme.Radius.md, shadow: false)
                .frame(width: 84)

            VStack(alignment: .leading, spacing: 6) {
                Text(status.item.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                if let next = status.next, let date = next.airDateValue {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundStyle(Theme.Colors.accent)
                        Text(formatDate(date))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .font(Theme.Typography.callout.weight(.semibold))
                    }
                    if let s = next.seasonNumber, let e = next.episodeNumber {
                        Text(String(format: "S%02d · E%02d%@", s, e, next.name.map { " · \($0)" } ?? ""))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Noch nichts angekündigt")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            Spacer()
        }
        .cineoCard(padding: Theme.Spacing.sm)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateStyle = .full
        f.timeStyle = .none
        return f.string(from: date)
    }
}
