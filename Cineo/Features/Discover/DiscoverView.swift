import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DiscoverView: View {

    @Environment(LibraryRepository.self) private var library
    @Environment(DismissedRepository.self) private var dismissed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = DiscoverViewModel()
    @State private var ratingDraft: Int = 0
    @State private var ratingCandidate: DiscoverViewModel.Candidate?
    @State private var offset: CGSize = .zero
    @State private var didInitialLoad: Bool = false
    @State private var didCrossThreshold: Bool = false
    @State private var flyingOut: Bool = false

    private let swipeThreshold: CGFloat = 110
    private let maxRotation: Double = 12

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
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.accentLight)
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
        .sheet(item: $ratingCandidate) { candidate in
            RatingSheet(
                title: candidate.title,
                rating: $ratingDraft,
                onSave: { value in
                    Task {
                        let item = viewModel.toLibraryItem(candidate, rating: value, watched: true)
                        await library.add(item)
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
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            cardStack
                .padding(.horizontal, Theme.Spacing.md)
            Spacer(minLength: Theme.Spacing.lg)
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
            CircleActionButton(symbol: "xmark", kind: .neutral, size: Theme.Layout.circleActionMd) {
                triggerSwipe(.left, for: candidate)
            }
            CircleActionButton(symbol: "plus", kind: .accent, size: Theme.Layout.circleActionLg) {
                Task { await plusAction(candidate) }
            }
            CircleActionButton(symbol: "eye.fill", kind: .neutral, size: Theme.Layout.circleActionMd) {
                triggerSwipe(.right, for: candidate)
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

    private func triggerSwipe(_ direction: SwipeDirection, for candidate: DiscoverViewModel.Candidate) {
        hapticConfirm()
        if reduceMotion {
            flyingOut = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                finalizeSwipe(direction, candidate: candidate)
            }
        } else {
            withAnimation(.easeOut(duration: 0.28)) {
                offset = CGSize(width: 900 * direction.sign, height: offset.height + 60)
                flyingOut = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                finalizeSwipe(direction, candidate: candidate)
            }
        }
    }

    private func finalizeSwipe(_ direction: SwipeDirection, candidate: DiscoverViewModel.Candidate) {
        Task {
            switch direction {
            case .left:
                await dismissed.dismiss(tmdbId: candidate.tmdbId, mediaType: candidate.mediaType)
            case .right:
                ratingDraft = 0
                ratingCandidate = candidate
            }
            viewModel.popTop()
            offset = .zero
            flyingOut = false
        }
    }

    private func plusAction(_ candidate: DiscoverViewModel.Candidate) async {
        hapticConfirm()
        let item = viewModel.toLibraryItem(candidate, rating: nil, watched: false)
        await library.add(item)
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.28)) {
                offset = CGSize(width: 0, height: -800)
                flyingOut = true
            }
        } else {
            flyingOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            viewModel.popTop()
            offset = .zero
            flyingOut = false
        }
    }

    // MARK: - Haptics

    private func hapticEdge() {
#if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
#endif
    }

    private func hapticConfirm() {
#if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
#endif
    }

    // MARK: - Data

    private func reload() async {
        let libraryItems = library.items
        let dismissedIds = Set(dismissed.items.map(\.tmdbId))
        await viewModel.reload(library: libraryItems, dismissedIds: dismissedIds)
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
