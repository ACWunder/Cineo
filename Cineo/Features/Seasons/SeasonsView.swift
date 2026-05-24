import SwiftUI

struct SeasonsView: View {
    @Environment(LibraryRepository.self) private var library
    @State private var viewModel = SeasonsViewModel()
    /// Programmatic navigation so each row can push the detail view with
    /// a plain Button instead of a NavigationLink — that's what kills the
    /// iOS-default disclosure chevron in the List + lets the card expand
    /// into the freed space.
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    content
                }
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

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("Demnächst")
                .font(Theme.Typography.title2)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer(minLength: 0)
            filterMenu
        }
        .frame(height: 36)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xxs)
        .padding(.bottom, Theme.Spacing.xxs)
    }

    private var filterMenu: some View {
        @Bindable var vm = viewModel
        let isActive = vm.visibility != .active
        return Menu {
            ForEach(SeasonsViewModel.Visibility.allCases) { option in
                Button {
                    vm.visibility = option
                } label: {
                    Label(option.label, systemImage: vm.visibility == option ? "checkmark" : "")
                }
            }
            if !vm.hiddenIds.isEmpty {
                Divider()
                Text("\(vm.hiddenIds.count) ausgeblendet")
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle\(isActive ? ".fill" : "")")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(isActive ? Color(hex: 0x2A1A05) : Theme.Colors.accentLight)
                .frame(width: 34, height: 34)
                .background {
                    if isActive {
                        Circle().fill(Theme.Colors.accentGradient)
                        Circle().fill(Theme.Colors.accentSheen)
                            .blendMode(.plusLighter)
                            .opacity(0.35)
                            .allowsHitTesting(false)
                    } else {
                        Circle().fill(.ultraThinMaterial.opacity(0.5))
                    }
                }
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                )
                .animation(.easeInOut(duration: 0.18), value: isActive)
        }
        .accessibilityLabel("Filter")
    }

    @ViewBuilder
    private var content: some View {
        let hasAnySeries = library.items.contains(where: { $0.mediaType == .tv })
        if viewModel.isLoading && viewModel.upcoming.isEmpty {
            LoadingStateView(message: "Hole neue Folgen …")
        } else if !hasAnySeries {
            EmptyStateView(
                symbol: "tv",
                title: "Keine Serien",
                message: "Wenn du Serien hinzufügst, siehst du hier ihre nächsten Folgen."
            )
        } else if viewModel.upcoming.isEmpty {
            EmptyStateView(
                symbol: "calendar.badge.exclamationmark",
                title: "Nichts angekündigt",
                message: "Aktuell ist keine neue Folge bekannt."
            )
        } else if viewModel.visibleUpcoming.isEmpty {
            // Everything is hidden — give the user a one-tap exit so they
            // don't have to remember where the filter menu is.
            EmptyStateView(
                symbol: "eye.slash",
                title: "Alle ausgeblendet",
                message: "Du hast jede Serie hier auf stumm gestellt. Wechsel den Filter, um sie wieder zu sehen.",
                actionTitle: "Ausgeblendete anzeigen"
            ) {
                viewModel.visibility = .all
            }
        } else {
            list
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(viewModel.visibleUpcoming) { row in
                rowLink(row)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }

    /// One row entry: programmatic push (no NavigationLink → no chevron)
    /// plus the swipe-action and the muted visual treatment.
    @ViewBuilder
    private func rowLink(_ row: SeasonsViewModel.SeriesStatus) -> some View {
        let muted = viewModel.isHidden(row.id)
        Button {
            path.append(row.item)
        } label: {
            SeriesRow(status: row, muted: muted)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: Theme.Spacing.md, bottom: 4, trailing: Theme.Spacing.md))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                viewModel.toggleHidden(row.id)
            } label: {
                if muted {
                    Label("Einblenden", systemImage: "eye")
                } else {
                    Label("Ausblenden", systemImage: "eye.slash")
                }
            }
            .tint(muted ? Theme.Colors.accent : Theme.Colors.dismissTint)
        }
    }

}

private struct SeriesRow: View {
    let status: SeasonsViewModel.SeriesStatus
    var muted: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            PosterView(path: status.item.posterPath, size: "w342", radius: Theme.Radius.md, shadow: false)
                .frame(width: 84)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(status.item.title)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)
                    if muted {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
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
        .opacity(muted ? 0.45 : 1)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.setLocalizedDateFormatFromTemplate("EEE d. MMM yyyy") // Do. 15. Jan. 2026
        return f.string(from: date)
    }
}
