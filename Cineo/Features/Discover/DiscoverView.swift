import SwiftUI

struct DiscoverView: View {

    @Environment(LibraryRepository.self) private var library
    @Environment(DismissedRepository.self) private var dismissed

    @State private var viewModel = DiscoverViewModel()
    @State private var ratingDraft: Int = 0
    @State private var ratingCandidate: DiscoverViewModel.Candidate?
    @State private var offset: CGSize = .zero
    @State private var didInitialLoad: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Empfehlungen")
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Theme.Colors.accent)
                    }
                }
            }
        }
        .task {
            if !didInitialLoad {
                didInitialLoad = true
                await reload()
            }
        }
        .onChange(of: library.items.map(\.tmdbId)) { _, _ in
            if !didInitialLoad { return }
        }
        .sheet(item: $ratingCandidate) { candidate in
            RatingSheet(
                title: candidate.title,
                rating: $ratingDraft,
                onSave: { value in
                    Task {
                        let item = viewModel.toLibraryItem(candidate, rating: value, watched: true)
                        await library.add(item)
                        viewModel.popTop()
                        ratingDraft = 0
                        ratingCandidate = nil
                    }
                },
                onCancel: {
                    ratingDraft = 0
                    ratingCandidate = nil
                }
            )
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.stack.isEmpty {
            LoadingStateView(message: "Berechne Empfehlungen …")
        } else if let error = viewModel.error, viewModel.stack.isEmpty {
            EmptyStateView(
                symbol: "exclamationmark.triangle",
                title: "Konnte nichts laden",
                message: error,
                actionTitle: "Erneut versuchen"
            ) {
                Task { await reload() }
            }
        } else if viewModel.stack.isEmpty {
            EmptyStateView(
                symbol: viewModel.emptyLibrary ? "sparkles" : "checkmark.seal",
                title: viewModel.emptyLibrary ? "Bewerte ein paar Titel" : "Alles gesichtet",
                message: viewModel.emptyLibrary
                    ? "Füge Filme oder Serien in der Suche hinzu und bewerte sie. Dann lernt Cineo deinen Geschmack kennen."
                    : "Komm später wieder — oder lade neue Vorschläge."
            )
        } else {
            stackView
        }
    }

    private var stackView: some View {
        VStack {
            Spacer(minLength: 0)
            ZStack {
                ForEach(Array(viewModel.stack.prefix(3).enumerated()).reversed(), id: \.element.id) { entry in
                    let depth = entry.offset
                    let candidate = entry.element
                    DiscoverCardView(candidate: candidate)
                        .scaleEffect(1 - CGFloat(depth) * 0.04)
                        .offset(y: CGFloat(depth) * 14)
                        .offset(depth == 0 ? offset : .zero)
                        .rotationEffect(depth == 0 ? .degrees(Double(offset.width) / 20) : .zero)
                        .zIndex(Double(10 - depth))
                        .gesture(depth == 0 ? dragGesture(for: candidate) : nil)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: offset)
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, Theme.Spacing.md)

            Spacer(minLength: Theme.Spacing.md)

            if let top = viewModel.stack.first {
                actionButtons(for: top)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }

    private func actionButtons(for candidate: DiscoverViewModel.Candidate) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            CircleActionButton(symbol: "xmark", kind: .neutral) {
                Task { await dismissAction(candidate) }
            }
            CircleActionButton(symbol: "plus", kind: .accent, size: 84) {
                Task { await addAction(candidate) }
            }
            CircleActionButton(symbol: "eye", kind: .neutral) {
                ratingDraft = 0
                ratingCandidate = candidate
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dragGesture(for candidate: DiscoverViewModel.Candidate) -> some Gesture {
        DragGesture()
            .onChanged { value in offset = value.translation }
            .onEnded { value in
                let threshold: CGFloat = 120
                if value.translation.width < -threshold {
                    Task { await dismissAction(candidate) }
                } else if value.translation.width > threshold {
                    Task { await addAction(candidate) }
                } else {
                    offset = .zero
                }
            }
    }

    private func reload() async {
        let libraryItems = library.items
        let dismissedIds = Set(dismissed.items.map(\.tmdbId))
        await viewModel.reload(library: libraryItems, dismissedIds: dismissedIds)
    }

    private func addAction(_ candidate: DiscoverViewModel.Candidate) async {
        let item = viewModel.toLibraryItem(candidate, rating: nil, watched: false)
        await library.add(item)
        withAnimation { viewModel.popTop(); offset = .zero }
    }

    private func dismissAction(_ candidate: DiscoverViewModel.Candidate) async {
        await dismissed.dismiss(tmdbId: candidate.tmdbId, mediaType: candidate.mediaType)
        withAnimation { viewModel.popTop(); offset = .zero }
    }
}
