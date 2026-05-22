import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DiscoverView: View {

    @Environment(LibraryRepository.self) private var library
    @Environment(DismissedRepository.self) private var dismissed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = DiscoverViewModel()
    @State private var ratingCandidate: DiscoverViewModel.Candidate?
    @State private var offset: CGSize = .zero
    @State private var didInitialLoad: Bool = false
    @State private var didCrossThreshold: Bool = false
    @State private var flyingOut: Bool = false
    @State private var path = NavigationPath()

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
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibraryItem.self) { item in
                LibraryDetailView(item: item)
            }
        }
        .task {
            if !didInitialLoad {
                didInitialLoad = true
                await reload()
            }
        }
        .onChange(of: library.items.count) { _, _ in
            // Library changed → recompute the pool, but keep every card the
            // user can currently see stable. Re-mixing happens silently
            // beyond the visible stack.
            guard didInitialLoad else { return }
            Task { await reload(preserveVisible: 3) }
        }
        .onChange(of: dismissed.items.count) { _, _ in
            guard didInitialLoad else { return }
            Task { await reload(preserveVisible: 3) }
        }
    }

    private var topBar: some View {
        HStack {
            filterChips
            Spacer(minLength: 0)
        }
        .frame(height: 40)   // matches the previous reload-button height so the
                             // filter chips sit at the same vertical position
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private var filterChips: some View {
        @Bindable var vm = viewModel
        return HStack(spacing: 6) {
            ForEach(DiscoverViewModel.MediaFilter.allCases) { option in
                let isActive = vm.filter == option
                Button {
                    vm.filter = option
                } label: {
                    Text(option.label)
                        .font(Theme.Typography.footnote.weight(.semibold))
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
                .buttonStyle(CineoPressStyle(scale: 0.94))
            }
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
        // centered while still guaranteeing a minimum breathing room top &
        // bottom.
        VStack(spacing: 0) {
            Spacer(minLength: Theme.Spacing.sm)
            cardStack
                .padding(.horizontal, Theme.Spacing.md)
            Spacer(minLength: Theme.Spacing.sm)
            if let top = viewModel.stack.first {
                actionButtons(for: top)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
            }
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
        if reduceMotion {
            flyingOut = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                finalizeSwipe(direction, candidate: candidate)
            }
        } else {
            withAnimation(.easeOut(duration: duration)) {
                offset = CGSize(width: 900 * direction.sign, height: offset.height + 60)
                flyingOut = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                finalizeSwipe(direction, candidate: candidate)
            }
        }
    }

    private func finalizeSwipe(_ direction: SwipeDirection, candidate: DiscoverViewModel.Candidate) {
        Task {
            switch direction {
            case .left:
                await dismissed.dismiss(tmdbId: candidate.tmdbId, mediaType: candidate.mediaType)
                popAndMaybeRefill()
            case .right:
                // Right swipe = "Gesehen" — open rating overlay without removing
                // the card from the stack until the user finishes the overlay.
                openRating(for: candidate)
            }
            offset = .zero
            flyingOut = false
        }
    }

    // MARK: - Watchlist / Rating

    private func openRating(for candidate: DiscoverViewModel.Candidate) {
        hapticConfirm()
        ratingCandidate = candidate
    }

    private func commitRating(_ value: Int?, for candidate: DiscoverViewModel.Candidate) {
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

    private func reload(preserveVisible: Int = 0) async {
        let libraryItems = library.items
        let dismissedIds = Set(dismissed.items.map(\.tmdbId))
        await viewModel.reload(
            library: libraryItems,
            dismissedIds: dismissedIds,
            preserveVisible: preserveVisible
        )
    }

    /// Wrap viewModel.popTop with an auto-refill when the deck almost runs
    /// out. We preserve whatever stack is left so the user's view never
    /// shuffles under them — only the off-screen tail gets refreshed.
    private func popAndMaybeRefill() {
        viewModel.popTop()
        if viewModel.stack.count <= 1 && !viewModel.isLoading {
            let visibleAfterPop = viewModel.stack.count
            Task { await reload(preserveVisible: visibleAfterPop) }
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
