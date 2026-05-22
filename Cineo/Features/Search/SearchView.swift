import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var pendingAdd: TMDBSearchMultiResult?

    @Environment(LibraryRepository.self) private var library

    var body: some View {
        NavigationStack {
            @Bindable var vm = viewModel
            content
                .navigationTitle("Suche")
                .toolbarBackground(Theme.Colors.background, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .searchable(text: $vm.query,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Film oder Serie suchen")
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .task(id: viewModel.query) {
                    try? await Task.sleep(for: .milliseconds(300))
                    if !Task.isCancelled { await viewModel.search() }
                }
        }
        .sheet(item: $pendingAdd) { item in
            AddTitleSheet(result: item)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                EmptyStateView(
                    symbol: "magnifyingglass",
                    title: "Was willst du heute schauen?",
                    message: "Suche nach Filmen oder Serien und füge sie deiner Bibliothek hinzu."
                )
            } else if viewModel.isLoading && viewModel.results.isEmpty {
                LoadingStateView(message: "Suche …")
            } else if let error = viewModel.error {
                EmptyStateView(
                    symbol: "exclamationmark.triangle",
                    title: "Hat nicht geklappt",
                    message: error
                )
            } else if viewModel.results.isEmpty {
                EmptyStateView(
                    symbol: "moon.zzz",
                    title: "Keine Treffer",
                    message: "Versuch einen anderen Suchbegriff."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.results, id: \.id) { item in
                            SearchResultRow(result: item, isInLibrary: library.contains(tmdbId: item.id)) {
                                pendingAdd = item
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
            }
        }
    }
}

private struct SearchResultRow: View {
    let result: TMDBSearchMultiResult
    let isInLibrary: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            PosterView(path: result.posterPath, size: "w185", radius: Theme.Radius.sm, shadow: false)
                .frame(width: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayTitle)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

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

            Spacer()

            Button(action: onAdd) {
                Image(systemName: isInLibrary ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(isInLibrary ? Theme.Colors.success : Theme.Colors.accent)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .disabled(isInLibrary)
        }
        .cineoCard(padding: Theme.Spacing.sm)
    }
}
