import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DiscoverView: View {

    @Environment(LibraryRepository.self) private var library
    @Environment(DismissedRepository.self) private var dismissed
    @Environment(AuthService.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = DiscoverViewModel()
    @State private var ratingCandidate: DiscoverViewModel.Candidate?
    /// Live drag offset of the top card — also drives the
    /// programmatic fly-offs from the X/+/eye buttons. One state,
    /// one implicit animation, one code path for both gesture-driven
    /// swipes and button taps. (Pattern taken from the Lieblingsgerichte
    /// app's HomeView, which feels smooth precisely because of this
    /// simplicity.)
    @State private var translation: CGSize = .zero
    @State private var didInitialLoad: Bool = false
    @State private var didCrossThreshold: Bool = false
    @State private var path = NavigationPath()
    @State private var showLogoutConfirm: Bool = false

    /// IDs the user has dismissed in this session, kept locally so the
    /// next `reload` excludes them immediately — without waiting for the
    /// Firestore write + snapshot listener round-trip.
    @State private var locallyDismissed: Set<Int> = []

    /// Handle on the currently-running reload Task so a fresh source-mode
    /// toggle can cancel the in-flight one — keeps URLSession calls from
    /// burning bandwidth on data the user no longer wants.
    @State private var currentReloadTask: Task<Void, Never>?

    /// Last few actions the user has performed on the deck, capped at
    /// `maxUndo`. Drives the back button in the top bar.
    @State private var undoStack: [UndoEntry] = []
    private let maxUndo = 5

    private enum UndoEntry {
        case dismissed(DiscoverViewModel.Candidate)
        case addedToWatchlist(DiscoverViewModel.Candidate)
        case rated(DiscoverViewModel.Candidate)
    }

    /// Drives the matchedGeometry slide of the active capsule between
    /// the two source-toggle segments.
    @Namespace private var sourceToggleNS

    private let swipeThreshold: CGFloat = 100
    private let maxRotation: Double = 12
    private let swipeDuration: Double = 0.3

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    sourceToggle
                    content
                }
                if let candidate = ratingCandidate {
                    RatingOverlay(
                        title: candidate.title,
                        posterPath: candidate.posterPath,
                        onRate: { value in commitRating(value, for: candidate) },
                        onSkip: { commitRating(nil, for: candidate) },
                        onCancel: { ratingCandidate = nil }
                    )
                    .zIndex(99)
                    .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.spring, value: ratingCandidate)
                }
                if showLogoutConfirm {
                    logoutDropdown
                        .zIndex(100)
                }
            }
            .animation(Theme.Motion.pop, value: showLogoutConfirm)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibraryItem.self) { item in
                LibraryDetailView(item: item)
            }
        }
        .task {
            if !didInitialLoad {
                // Wait until both the library and the dismissed snapshots
                // have actually arrived from Firestore. Otherwise the first
                // reload runs against an empty library and briefly shows
                // candidates that are already saved/dismissed before swapping
                // them out when the snapshot finally lands.
                await waitForInitialSnapshots()
                didInitialLoad = true
                startReload()
            }
        }
        .onChange(of: library.items.count) { _, _ in
            // Adding something to the library / watchlist re-ranks the pool,
            // but the top 5 cards stay rock-stable so the visible deck never
            // shuffles under the user.
            guard didInitialLoad else { return }
            startReload(preserveVisible: 5)
        }
        .onChange(of: viewModel.sourceMode) { _, _ in
            // Switching between "Für dich" and "Angesagt" swaps the entire
            // pool — refetch from scratch instead of preserving anything.
            // Cancel the in-flight reload so URLSession drops the previous
            // mode's calls and the user's latest tap wins.
            guard didInitialLoad else { return }
            viewModel.excludedGenres = []
            startReload()
        }
        .onChange(of: viewModel.stack.count) { _, newCount in
            // Low-water mark: when the visible stack thins out, pull the
            // next page in the background so the user never hits an empty
            // deck mid-swipe. Skips itself while a load is in flight or
            // the underlying pool is exhausted (no more pages on TMDB).
            guard didInitialLoad else { return }
            guard newCount <= 5 else { return }
            guard !viewModel.isLoadingMore, !viewModel.isExhausted else { return }
            Task { await loadMore() }
        }
        // Intentionally *no* onChange for dismissed: dismissing a card must
        // never trigger a recompute. popTop already removes it from the
        // local pool, and reloading here could race the snapshot listener
        // and momentarily re-include the dismissed item.
    }

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            mediaTypeMenu
            genreMenu
            Spacer(minLength: 0)
            undoButton
            profileButton
        }
        .frame(height: 36)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xxs)
        .padding(.bottom, Theme.Spacing.xxs)
    }

    private var sourceToggle: some View {
        HStack(spacing: 0) {
            sourceSegment(.library)
            sourceSegment(.trending)
        }
        .padding(2)
        .background(Theme.Colors.backgroundElevated, in: Capsule())
        .overlay(
            Capsule().stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.5
            )
        )
        .frame(maxWidth: 240)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, 6)
    }

    private func sourceSegment(_ mode: DiscoverViewModel.SourceMode) -> some View {
        let isActive = viewModel.sourceMode == mode
        return Button {
            guard !isActive else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                viewModel.sourceMode = mode
            }
            hapticConfirm()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .symbolEffect(.bounce, value: viewModel.sourceMode)
                Text(mode.label)
                    .font(Theme.Typography.caption.weight(.semibold))
            }
            .foregroundStyle(isActive ? Color(hex: 0x2A1A05) : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background {
                if isActive {
                    ZStack {
                        Capsule().fill(Theme.Colors.accentGradient)
                        Capsule().fill(Theme.Colors.accentSheen)
                            .blendMode(.plusLighter)
                            .opacity(0.35)
                            .allowsHitTesting(false)
                    }
                    .matchedGeometryEffect(id: "activeSource", in: sourceToggleNS)
                    .shadow(color: Theme.Colors.accentGlow.opacity(0.45), radius: 8, y: 2)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var undoButton: some View {
        Button {
            undoLast()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.accentLight)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial.opacity(0.5), in: Circle())
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
        }
        .buttonStyle(CineoPressStyle(scale: 0.92))
        .opacity(undoStack.isEmpty ? 0.3 : 1)
        .disabled(undoStack.isEmpty)
        .animation(.easeInOut(duration: 0.15), value: undoStack.isEmpty)
        .accessibilityLabel("Letzte Aktion rückgängig")
    }

    private var profileButton: some View {
        Button {
            showLogoutConfirm = true
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.accentLight)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial.opacity(0.5), in: Circle())
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
        }
        .buttonStyle(CineoPressStyle(scale: 0.92))
        .accessibilityLabel("Profil")
    }

    private var logoutDropdown: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { showLogoutConfirm = false }

            Button {
                showLogoutConfirm = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    auth.signOut()
                }
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("Abmelden")
                        .font(Theme.Typography.callout.weight(.semibold))
                }
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 16, y: 8)
            }
            .buttonStyle(CineoPressStyle(scale: 0.94))
            .padding(.top, 56)
            .padding(.trailing, Theme.Spacing.md)
            .transition(.scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity))
        }
    }

    private var mediaTypeMenu: some View {
        @Bindable var vm = viewModel
        let isActive = vm.filter != .all
        return Menu {
            ForEach(DiscoverViewModel.MediaFilter.allCases) { option in
                Button {
                    vm.filter = option
                } label: {
                    Label(option.label,
                          systemImage: vm.filter == option ? "checkmark" : "")
                }
            }
        } label: {
            FilterPill(
                icon: "film.stack",
                text: vm.filter == .all ? "Typ" : vm.filter.label,
                isActive: isActive,
                minWidth: 88
            )
        }
    }

    private var genreMenu: some View {
        @Bindable var vm = viewModel
        let genres = vm.availableGenres
        let isActive = !vm.excludedGenres.isEmpty
        return Menu {
            Button("Zurücksetzen", role: .destructive) {
                vm.excludedGenres = []
            }
            .disabled(!isActive)
            Divider()
            ForEach(genres, id: \.self) { genre in
                // Same exclusion model + Color.clear placeholder trick as
                // LibraryView.genreMenu — see the comments there for the
                // reasoning behind the conditional view.
                Button {
                    if vm.excludedGenres.contains(genre) {
                        vm.excludedGenres.remove(genre)
                    } else {
                        vm.excludedGenres.insert(genre)
                    }
                } label: {
                    HStack {
                        if vm.excludedGenres.contains(genre) {
                            Color.clear.frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "checkmark")
                        }
                        Text(genre)
                    }
                }
                .menuActionDismissBehavior(.disabled)
            }
        } label: {
            FilterPill(
                icon: "tag.fill",
                text: "Genre",
                isActive: isActive,
                minWidth: 108
            )
        }
        .disabled(genres.isEmpty)
    }

    @ViewBuilder
    private var content: some View {
        if (viewModel.isLoading || viewModel.isLoadingMore) && viewModel.stack.isEmpty {
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
            if viewModel.sourceMode == .trending {
                EmptyStateView(
                    symbol: "arrow.clockwise",
                    title: "Alles durch",
                    message: "Du hast den aktuellen Stapel komplett weggewischt. Lade ihn frisch nach.",
                    actionTitle: "Stapel neu laden"
                ) {
                    refreshTrending()
                }
            } else {
                EmptyStateView(
                    symbol: viewModel.emptyLibrary ? "sparkles" : "checkmark.seal",
                    title: viewModel.emptyLibrary ? "Bewerte ein paar Titel" : "Alles gesichtet",
                    message: viewModel.emptyLibrary
                        ? "Füge Filme oder Serien in der Bibliothek hinzu und bewerte sie. Dann lernt Cineo deinen Geschmack kennen."
                        : "Komm später wieder — oder lade neue Vorschläge."
                )
            }
        } else {
            stackView
        }
    }

    private var stackView: some View {
        // Card is centered vertically between the top bar and the action
        // buttons. Two spacers with the same minLength keep the card visually
        // centered while still guaranteeing a comfortable breathing room
        // above and below.
        VStack(spacing: 0) {
            Spacer(minLength: Theme.Spacing.md)
            ZStack {
                posterPrefetcher
                cardStack
            }
            .padding(.horizontal, Theme.Spacing.md)
            Spacer(minLength: Theme.Spacing.md)
            if let top = viewModel.stack.first {
                actionButtons(for: top)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }

    /// Renders 1×1 invisible `PosterView`s for the candidates queued
    /// just past the visible top-3. Each one runs its `.task` and
    /// drops the decoded bitmap into the shared `PosterImageCache`,
    /// so by the time the card actually rises into a visible depth
    /// slot, `PosterView.init` pulls the image straight from cache
    /// on the very first frame — no placeholder, no late "popping
    /// in" of a poster.
    private var posterPrefetcher: some View {
        ZStack {
            ForEach(viewModel.stack.dropFirst(3).prefix(5), id: \.id) { candidate in
                PosterView(
                    path: candidate.posterPath,
                    size: "w500",
                    radius: 0,
                    shadow: false
                )
                .frame(width: 1, height: 1)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Card stack
    //
    // Lieblingsgerichte HomeView pattern, transplanted as-is:
    //   * one `translation: CGSize` drives the top card
    //   * cards behind get a static y offset based on their depth
    //   * `.animation(.easeInOut(duration: 0.3), value: translation)`
    //     is the only animation modifier; it handles drag tracking,
    //     bounce-back on a partial drag, and the fly-off itself
    //   * a fly-off is just `withAnimation { translation = ±800 }`
    //     followed by a `DispatchQueue.main.asyncAfter` that resets
    //     translation AND advances the model — no separate departing
    //     layer, no completion callbacks, no two-tick hacks
    //
    // The X / + / eye buttons call the exact same functions as the
    // swipe paths, so a button tap and a flick are visually
    // indistinguishable.

    private var cardStack: some View {
        ZStack {
            ForEach(Array(viewModel.stack.prefix(3).enumerated()).reversed(), id: \.element.id) { entry in
                let depth = entry.offset
                let candidate = entry.element
                let isTop = depth == 0

                DiscoverCardView(candidate: candidate)
                    .overlay(alignment: .top) {
                        if isTop {
                            swipeOverlay
                                .padding(Theme.Spacing.lg)
                        }
                    }
                    .offset(
                        x: isTop ? translation.width : 0,
                        y: CGFloat(depth) * 14 + (isTop ? translation.height : 0)
                    )
                    .rotationEffect(isTop ? .degrees(rotationAngle) : .zero, anchor: .bottom)
                    .zIndex(Double(10 - depth))
                    .gesture(isTop ? dragGesture(for: candidate) : nil)
                    .onTapGesture {
                        if isTop {
                            path.append(viewModel.toLibraryItem(candidate, rating: nil, watched: false))
                        }
                    }
                    .animation(reduceMotion
                               ? Theme.Motion.reduced
                               : .easeInOut(duration: swipeDuration),
                               value: translation)
                    .transition(.identity)
                    .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: 520)
    }

    private var swipeOverlay: some View {
        HStack {
            SwipeBadge(
                text: "PASS",
                tint: Theme.Colors.dismissTint,
                rotation: -10
            )
            .opacity(max(0, Double(-translation.width / swipeThreshold)))
            Spacer()
            SwipeBadge(
                text: "GESEHEN",
                tint: Theme.Colors.accentLight,
                rotation: 10
            )
            .opacity(max(0, Double(translation.width / swipeThreshold)))
        }
    }

    private var rotationAngle: Double {
        let raw = Double(translation.width) / 20
        return max(-maxRotation, min(maxRotation, raw))
    }

    // MARK: - Actions

    private func actionButtons(for candidate: DiscoverViewModel.Candidate) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            CircleActionButton(symbol: "xmark", kind: .neutral, size: Theme.Layout.circleActionLg) {
                dismiss(candidate)
            }
            CircleActionButton(symbol: "plus", kind: .ghost, size: Theme.Layout.circleActionSm) {
                addToWatchlist(candidate)
            }
            // Eye opens the rating overlay directly — no fly-off
            // animation. The sheet appearing IS the feedback.
            CircleActionButton(symbol: "eye.fill", kind: .accent, size: Theme.Layout.circleActionLg) {
                openRating(for: candidate)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dragGesture(for candidate: DiscoverViewModel.Candidate) -> some Gesture {
        DragGesture()
            .onChanged { value in
                translation = value.translation

                let crossed = abs(value.translation.width) > swipeThreshold
                if crossed && !didCrossThreshold {
                    didCrossThreshold = true
                    hapticEdge()
                } else if !crossed && didCrossThreshold {
                    didCrossThreshold = false
                }
            }
            .onEnded { value in
                didCrossThreshold = false
                if value.translation.width < -swipeThreshold {
                    dismiss(candidate)
                } else if value.translation.width > swipeThreshold {
                    promptRate(candidate)
                } else {
                    // Implicit `.animation(value: translation)` on
                    // the card handles the bounce — no withAnimation
                    // needed here.
                    translation = .zero
                }
            }
    }

    // MARK: - Specific actions (gesture + button share these)

    private func dismiss(_ candidate: DiscoverViewModel.Candidate) {
        hapticConfirm()
        locallyDismissed.insert(candidate.tmdbId)
        flyOffAndAdvance(translationEnd: CGSize(width: -800, height: 0)) {
            viewModel.popTop()
            recordUndo(.dismissed(candidate))
            Task {
                await dismissed.dismiss(tmdbId: candidate.tmdbId, mediaType: candidate.mediaType)
            }
        }
    }

    private func addToWatchlist(_ candidate: DiscoverViewModel.Candidate) {
        hapticConfirm()
        let item = viewModel.toLibraryItem(candidate, rating: nil, watched: false)
        flyOffAndAdvance(translationEnd: CGSize(width: 0, height: -800)) {
            viewModel.popTop()
            recordUndo(.addedToWatchlist(candidate))
            Task { await library.add(item) }
        }
    }

    private func promptRate(_ candidate: DiscoverViewModel.Candidate) {
        hapticConfirm()
        flyOffAndAdvance(translationEnd: CGSize(width: 800, height: 0)) {
            ratingCandidate = candidate
            // Model intact: if the user cancels the rating, the
            // candidate is still the top of the stack at .zero.
        }
    }

    /// Animates the top card to `translationEnd` over `swipeDuration`,
    /// then on the next runloop tick after the animation completes
    /// snaps the translation back to `.zero` and runs `advance`
    /// (typically `viewModel.popTop()` plus any side effects).
    ///
    /// The reset + advance both happen in the same closure so they
    /// land in one render: the leaving card disappears (popTop
    /// removed it from the ForEach), the next card is now top at
    /// translation `.zero` (center). User's eye is on the off-screen
    /// trajectory, never notices the model jump.
    private func flyOffAndAdvance(translationEnd: CGSize, advance: @escaping () -> Void) {
        withAnimation(reduceMotion
                      ? Theme.Motion.reduced
                      : .easeInOut(duration: swipeDuration)) {
            translation = translationEnd
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + swipeDuration) {
            translation = .zero
            advance()
        }
    }

    private func openRating(for candidate: DiscoverViewModel.Candidate) {
        hapticConfirm()
        ratingCandidate = candidate
    }

    private func commitRating(_ value: Double?, for candidate: DiscoverViewModel.Candidate) {
        let item = viewModel.toLibraryItem(candidate, rating: value, watched: true)
        ratingCandidate = nil
        viewModel.popTop()
        recordUndo(.rated(candidate))
        Task { await library.add(item) }
    }

    // MARK: - Undo

    private func recordUndo(_ entry: UndoEntry) {
        undoStack.append(entry)
        if undoStack.count > maxUndo {
            undoStack.removeFirst(undoStack.count - maxUndo)
        }
    }

    private func undoLast() {
        guard let entry = undoStack.popLast() else { return }
        hapticConfirm()
        switch entry {
        case .dismissed(let c):
            locallyDismissed.remove(c.tmdbId)
            viewModel.unshift(c)
            Task { await dismissed.undismiss(tmdbId: c.tmdbId) }
        case .addedToWatchlist(let c), .rated(let c):
            viewModel.unshift(c)
            Task { await library.remove(tmdbId: c.tmdbId) }
        }
    }

    // MARK: - Haptics

    private func hapticEdge() {
        HapticEngine.shared.edge()
    }

    private func hapticConfirm() {
        HapticEngine.shared.confirm()
    }

    // MARK: - Data

    /// Polls until both Firestore repositories have delivered their first
    /// snapshot. Caps at ~3 seconds so a slow network doesn't keep the user
    /// staring at the empty stack — after that the reload runs anyway.
    private func waitForInitialSnapshots() async {
        let deadline = Date().addingTimeInterval(3.0)
        while !(library.hasLoadedInitial && dismissed.hasLoadedInitial) {
            if Date() >= deadline { return }
            try? await Task.sleep(for: .milliseconds(40))
            if Task.isCancelled { return }
        }
    }

    /// Build the `[tmdbId: Date]` snapshot of dismissals from Firestore
    /// items + session-local set. Shared by `reload` and `loadMore` so the
    /// revival/exclusion logic in the VM sees identical inputs.
    private func currentDismissedAtById() -> [Int: Date] {
        let now = Date()
        var rec: [Int: Date] = [:]
        for item in dismissed.items {
            rec[item.tmdbId] = item.dismissedAt ?? now
        }
        for id in locallyDismissed where rec[id] == nil {
            rec[id] = now
        }
        return rec
    }

    private func loadMore() async {
        await viewModel.loadMore(
            library: library.items,
            dismissedAtById: currentDismissedAtById()
        )
    }

    /// Cancel any in-flight reload and kick off a new one. Keeping a single
    /// handle means rapid toggle taps never leave two reloads racing — each
    /// fresh tap supersedes the previous one all the way down to URLSession.
    private func startReload(preserveVisible: Int = 0) {
        currentReloadTask?.cancel()
        currentReloadTask = Task { await reload(preserveVisible: preserveVisible) }
    }

    /// "Stapel neu laden" button on the Angesagt empty state. Drops the
    /// dismissal filter entirely so every trending item the user just
    /// swiped past is back in the deck. The Firestore dismissal log is
    /// left intact — only this fetch ignores it.
    private func refreshTrending() {
        currentReloadTask?.cancel()
        currentReloadTask = Task {
            await viewModel.reload(
                library: library.items,
                dismissedAtById: [:],
                preserveVisible: 0
            )
        }
    }

    private func reload(preserveVisible: Int = 0) async {
        let libraryItems = library.items
        // Union with the session-local set so freshly-dismissed cards
        // are excluded even when the Firestore listener hasn't yet
        // delivered the snapshot containing them. The local set only
        // ever grows; Firestore is still the persistent source of
        // truth across sessions.
        //
        // We pass the dismissal timestamp through so the ViewModel can
        // apply the 7-day revival rule. Session-local dismissals get
        // `Date()` (just now); persisted items use whatever Firestore
        // returned (older docs without the field are treated as recent
        // so legacy dismissals don't suddenly flood back in).
        let dismissedAtById = currentDismissedAtById()
        await viewModel.reload(
            library: libraryItems,
            dismissedAtById: dismissedAtById,
            preserveVisible: preserveVisible
        )
        // The reload above takes seconds (it fans out multiple TMDB
        // calls per rated title). During that time the user keeps
        // mashing X — those new dismissals land in `locallyDismissed`
        // but the in-flight reload already snapshotted its own state
        // and is blind to them. After the new pool is committed to
        // the stack, sweep out anything the user dismissed mid-reload
        // so the same cards never reappear.
        let snapshottedIds = Set(dismissedAtById.keys)
        let freshDismissed = Set(dismissed.items.map(\.tmdbId))
            .union(locallyDismissed)
            .subtracting(snapshottedIds)
        if !freshDismissed.isEmpty {
            viewModel.removeIDs(freshDismissed)
        }
    }

}

// MARK: - Swipe badge

private struct SwipeBadge: View {
    let text: String
    let tint: Color
    let rotation: Double

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .tracking(2)
            .foregroundStyle(tint)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(tint, lineWidth: 3)
            )
            .rotationEffect(.degrees(rotation))
    }
}
