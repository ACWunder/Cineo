import SwiftUI

/// Slim pill-shaped search field used by Library + Watchlist.
struct CineoSearchField: View {
    @Binding var text: String
    var placeholder: String = "Suchen …"
    var focus: FocusState<Bool>.Binding?

    @FocusState private var internalFocused: Bool

    private var isFocused: Bool {
        focus?.wrappedValue ?? internalFocused
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(isFocused ? Theme.Colors.accent : Theme.Colors.textSecondary)
                .animation(.easeInOut(duration: 0.18), value: isFocused)

            field

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 44)
        .background(Theme.Colors.backgroundElevated, in: Capsule())
        .overlay(
            Capsule().stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.5
            )
        )
    }

    @ViewBuilder
    private var field: some View {
        if let focus {
            TextField(placeholder, text: $text)
                .focused(focus)
                .modifier(SearchFieldStyle())
        } else {
            TextField(placeholder, text: $text)
                .focused($internalFocused)
                .modifier(SearchFieldStyle())
        }
    }
}

private struct SearchFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.callout)
            .foregroundStyle(Theme.Colors.accent)
            .tint(Theme.Colors.accent)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.search)
    }
}
