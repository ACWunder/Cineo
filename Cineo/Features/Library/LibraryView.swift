import SwiftUI

struct LibraryView: View {
    @Environment(LibraryRepository.self) private var library
    @State private var viewModel = LibraryViewModel()

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: Theme.Spacing.sm)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                if library.isLoading && library.items.isEmpty {
                    LoadingStateView(message: "Lade Bibliothek …")
                } else if library.items.isEmpty {
                    EmptyStateView(
                        symbol: "books.vertical",
                        title: "Noch leer hier",
                        message: "Suche Filme oder Serien und füge sie deiner Bibliothek hinzu."
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                            ForEach(viewModel.display(from: library.items)) { item in
                                NavigationLink(value: item) {
                                    LibraryGridCell(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                    }
                }
            }
            .navigationTitle("Bibliothek")
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { sortMenu }
                ToolbarItem(placement: .topBarLeading) { filterMenu }
            }
            .navigationDestination(for: LibraryItem.self) { item in
                LibraryDetailView(item: item)
            }
        }
    }

    private var sortMenu: some View {
        @Bindable var vm = viewModel
        return Menu {
            Picker("Sortieren", selection: $vm.sort) {
                ForEach(LibraryViewModel.Sort.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(Theme.Colors.accent)
        }
    }

    private var filterMenu: some View {
        @Bindable var vm = viewModel
        return Menu {
            Picker("Filter", selection: $vm.filter) {
                ForEach(LibraryViewModel.Filter.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(Theme.Colors.accent)
        }
    }
}

private struct LibraryGridCell: View {
    let item: LibraryItem
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            PosterView(path: item.posterPath, size: "w342", radius: Theme.Radius.md)
            Text(item.title)
                .font(Theme.Typography.callout.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
            HStack(spacing: 4) {
                if !item.year.isEmpty {
                    Text(item.year)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                if let r = item.rating {
                    Spacer()
                    StarRatingDisplay(rating: r, size: 11)
                }
            }
        }
    }
}
