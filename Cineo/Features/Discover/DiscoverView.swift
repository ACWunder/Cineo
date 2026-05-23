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
    @State private var offset: CGSize = .zero
    @State private var didInitialLoad: Bool = false
    @State private var didCrossThreshold: Bool = false
    @State private var flyingOut: Bool = false
    @State private var path = NavigationPath()
    @State private var showLogoutConfirm: Bool = false

    /// A snapshot of the card the user just dismissed, while it animates
    /// off-screen independently from the stack. Popping the stack runs
    /// the moment the swipe starts, so the next card rises into place
    /// right away — the leaving card just keeps flying outwards on its
    /// own layer.
    @State private var departingCard: DiscoverViewModel.Candidate?
    @State private var departingOffset: CGSize = .zero
    @State private var departingRotation: Double = 0
    @State private var departingOpacity: Double = 1

    private let swipeThreshold: CGFloat = 110
    private let maxRotation: Double = 12

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
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
                await reload()
            }
        }
        .onChange(of: library.items.count) { _, _ in
            // Adding something to the library / watchlist re-ranks the pool,
            // but the top 5 cards stay rock-stable so the visible deck never
            // shuffles under the user.
            guard didInitialLoad else { return }
            Task { await reload(preserveVisible: 5) }
        }
        // Intentionally *no* onChange for dismissed: dismissing a card must
        // never trigger a recompute. popTop already removes it from the
        // local pool, and reloading here could race the snapshot listener
        // and momentarily re-include the dismissed item.
    }

    private var topBar: some View {
        HStack {
            mediaTypeMenu
            Spacer(minLength: 0)
            profileButton
        }
        .frame(height: 40)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.sm)
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
                    // Defer the mutation past the Menu's dismiss frame and
                    // disable SwiftUI's diff animation so the grid swap
                    // doesn't compete with the closing menu for main-thread
                    // time. Selection feels instant; new posters fade in
                    // as their decode finishes.
                    DispatchQueue.main.async {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            vm.filter = option
                        }
                    }
                } label: {
                    Label(option.label,
                          systemImage: vm.filter == option ? "checkmark" : "")
                }
            }
        } label: {
            filterPillLabel(
                icon: "film.stack",
                text: vm.filter == .all ? "Typ" : vm.filter.label,
                isActive: isActive
            )
        }
    }

    private func filterPillLabel(icon: String, text: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text(text)
                .font(Theme.Typography.footnote.weight(.semibold))
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .opacity(0.7)
        }
        .foregroundStyle(isActive ? Color(hex: 0x2A1A05) : Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 7)
        .background(
            ZStack {
                if isActive {
                    Capsule().fill(Theme.Colors.accentGradient)
                    Capsule()
                        .fill(Theme.Colors.accentSheen)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                } else {
                    Capsule().fill(.ultraThinMaterial.opacity(0.4))
                }
            }
        )
        .overlay(
            Capsule().stroke(
                isActive ? Color.white.opacity(0.28) : Theme.Colors.border,
                lineWidth: 0.5
            )
        )
        .shadow(
            color: isActive ? Theme.Colors.accentGlow.opacity(0.55) : .clear,
            radius: 10, y: 4
        )
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
                    ? "Füge Filme oder Serien in der Bibliothek hinzu und bewerte sie. Dann lernt Cineo deinen Geschmack kennen."
                    : "Komm später wieder — oder lade neue Vorschläge."
            )
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
                cardStack
                departingOverlay
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

    @ViewBuilder
    private var departingOverlay: some View {
        if let departing = departingCard {
            DiscoverCardView(candidate: departing)
                .frame(maxWidth: 520)
                .offset(departingOffset)
                .rotationEffect(.degrees(departingRotation), anchor: .bottom)
                .opacity(departingOpacity)
                .allowsHitTesting(false)
                .zIndex(99)
        }
    }

    // MARK: - Card stack

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
                    .scaleEffect(stackScale(for: depth))
                    .offset(y: stackYOffset(for: depth))
                    .offset(isTop ? offset : .zero)
                    .rotationEffect(isTop ? .degrees(rotationAngle) : .zero, anchor: .bottom)
                    .opacity(isTop && flyingOut ? 0 : 1)
                    .zIndex(Double(10 - depth))
                    .gesture(isTop ? dragGesture(for: candidate) : nil)
                    .onTapGesture {
                        if isTop {
                            path.append(viewModel.toLibraryItem(candidate, rating: nil, watched: false))
                        }
                    }
                    .animation(motion, value: offset)
                    .animation(motion, value: flyingOut)
                    // When the stack pops a card, SwiftUI's default transition
                    // would otherwise fade/scale the disappearing card in place
                    // — that's the "ghost in the back" you saw. Cut it: the
                    // departingOverlay already shows the leaving card.
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
            .opacity(max(0, Double(-offset.width / swipeThreshold)))
            Spacer()
            SwipeBadge(
                text: "GESEHEN",
                tint: Theme.Colors.accentLight,
                rotation: 10
            )
            .opacity(max(0, Double(offset.width / swipeThreshold)))
        }
    }

    private var rotationAngle: Double {
        let raw = Double(offset.width) / 20
        return max(-maxRotation, min(maxRotation, raw))
    }

    private func stackScale(for depth: Int) -> CGFloat {
        if reduceMotion { return 1 }
        switch depth {
        case 0: return 1
        case 1: return 0.95
        default: return 0.9
        }
    }

    private func stackYOffset(for depth: Int) -> CGFloat {
        if reduceMotion { return 0 }
        return CGFloat(depth) * 14
    }

    private var motion: Animation { reduceMotion ? Theme.Motion.reduced : Theme.Motion.spring }

    // MARK: - Actions

    private func actionButtons(for candidate: DiscoverViewModel.Candidate) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            // X — dismiss with a slow, deliberate fly-out so the tap feels
            // intentional (a quick drag-swipe already feels good because the
            // finger carries the card most of the way; a tap starts at 0).
            CircleActionButton(symbol: "xmark", kind: .neutral, size: Theme.Layout.circleActionLg) {
                triggerSwipe(.left, for: candidate, duration: 1.1)
            }
            // Plus — smaller, transparent ghost — adds to watchlist
            CircleActionButton(symbol: "plus", kind: .ghost, size: Theme.Layout.circleActionSm) {
                Task { await addToWatchlist(candidate) }
            }
            // Eye — gold, opens rating overlay
            CircleActionButton(symbol: "eye.fill", kind: .accent, size: Theme.Layout.circleActionLg) {
                openRating(for: candidate)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dragGesture(for candidate: DiscoverViewModel.Candidate) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
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
                    triggerSwipe(.left, for: candidate)
                } else if value.translation.width > swipeThreshold {
                    triggerSwipe(.right, for: candidate)
                } else {
                    offset = .zero
                }
            }
    }

    private enum SwipeDirection {
        case left, right
        var sign: CGFloat { self == .right ? 1 : -1 }
    }

    private func triggerSwipe(_ direction: SwipeDirection,
                              for candidate: DiscoverViewModel.Candidate,
                              duration: Double = 0.28) {
        hapticConfirm()
        switch direction {
        case .left:
            // Detach the visible top card into a separate "departing" layer
            // and pop the stack immediately. Result: the next card rises
            // into place at the same moment the leaving card starts its
            // long slide off-screen — no delay between the two.
            startDeparture(candidate, direction: .left, duration: duration)
        case .right:
            // Right swipe keeps the card on stack; the rating overlay
            // decides what to do next.
            if reduceMotion {
                flyingOut = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    offset = .zero
                    flyingOut = false
                    openRating(for: candidate)
                }
            } else {
                withAnimation(.easeOut(duration: duration)) {
                    offset = CGSize(width: 900 * direction.sign, height: offset.height + 60)
                    flyingOut = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    offset = .zero
                    flyingOut = false
                    openRating(for: candidate)
                }
            }
        }
    }

    /// Snapshot the top card into `departingCard` (separate layer), then pop
    /// the stack so the next card starts rising right away. The departing
    /// layer keeps animating outwards for `duration` seconds independently.
    private func startDeparture(_ candidate: DiscoverViewModel.Candidate,
                                direction: SwipeDirection,
                                duration: Double) {
        let startingOffset = offset
        let startingRotation = rotationAngle

        departingCard = candidate
        departingOffset = startingOffset
        departingRotation = startingRotation
        departingOpacity = 1

        // Reset the stack offset so the next card sits naturally centered.
        offset = .zero
        flyingOut = false

        // Pop the model immediately. The depth/scale transitions of the
        // cards behind ride a soft slower spring so the next card glides
        // smoothly forward instead of snapping.
        withAnimation(.spring(response: 0.62, dampingFraction: 0.92)) {
            switch direction {
            case .left:
                Task { await dismissed.dismiss(tmdbId: candidate.tmdbId, mediaType: candidate.mediaType) }
                popAndMaybeRefill()
            case .right:
                popAndMaybeRefill()
            }
        }

        // Send the departing card off-screen. Reduced motion: short fade
        // instead of a slide.
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) {
                departingOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { clearDeparture() }
        } else {
            // Softer tween for taps that start from offset .zero — easeInOut
            // ramps in/out so the X-button doesn't kick the card abruptly.
            withAnimation(.easeInOut(duration: duration)) {
                departingOffset = CGSize(
                    width: 1100 * direction.sign,
                    height: startingOffset.height + 30
                )
                departingRotation = direction.sign > 0 ? 12 : -12
            }
            withAnimation(.easeIn(duration: duration * 0.5).delay(duration * 0.55)) {
                departingOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { clearDeparture() }
        }
    }

    private func clearDeparture() {
        departingCard = nil
        departingOffset = .zero
        departingRotation = 0
        departingOpacity = 1
    }

    // MARK: - Watchlist / Rating

    private func openRating(for candidate: DiscoverViewModel.Candidate) {
        hapticConfirm()
        ratingCandidate = candidate
    }

    private func commitRating(_ value: Double?, for candidate: DiscoverViewModel.Candidate) {
        let item = viewModel.toLibraryItem(candidate, rating: value, watched: true)
        // Optimistic UI: dismiss the overlay and advance the stack right away.
        // The Firestore write runs in the background — first-time save latency
        // was the reason the first rating felt sluggish.
        withAnimation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.spring) {
            ratingCandidate = nil
        }
        popAndMaybeRefill()
        Task { await library.add(item) }
    }

    private func addToWatchlist(_ candidate: DiscoverViewModel.Candidate) async {
        hapticConfirm()
        let item = viewModel.toLibraryItem(candidate, rating: nil, watched: false)
        await library.add(item)
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.28)) {
                offset = CGSize(width: 0, height: -700)
                flyingOut = true
            }
        } else {
            flyingOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            popAndMaybeRefill()
            offset = .zero
            flyingOut = false
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

    private func reload(preserveVisible: Int = 0) async {
        let libraryItems = library.items
        let dismissedIds = Set(dismissed.items.map(\.tmdbId))
        await viewModel.reload(
            library: libraryItems,
            dismissedIds: dismissedIds,
            preserveVisible: preserveVisible
        )
    }

    /// Plain pop. Refills are driven exclusively by library.items.count
    /// changes (add to watchlist / mark watched), so dismissing alone never
    /// triggers a recompute.
    private func popAndMaybeRefill() {
        viewModel.popTop()
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
