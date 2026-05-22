import SwiftUI

struct SeasonsView: View {
    @Environment(LibraryRepository.self) private var library
    @State private var viewModel = SeasonsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                content
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibraryItem.self) { item in
                LibraryDetailView(item: item)
            }
        }
        .task(id: library.items.map(\.tmdbId)) {
            await viewModel.reload(library: library.items)
        }
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
                            NavigationLink(value: row.item) {
                                SeriesRow(status: row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !viewModel.dormant.isEmpty {
                    sectionHeader("Keine neue Staffel angekündigt")
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.dormant) { row in
                            NavigationLink(value: row.item) {
                                SeriesRow(status: row)
                            }
                            .buttonStyle(.plain)
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
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
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .cineoRow(padding: Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.setLocalizedDateFormatFromTemplate("EEE d. MMM yyyy") // Do. 15. Jan. 2026
        return f.string(from: date)
    }
}
