import SwiftUI

// MARK: - Reusable capsule action button (icon + title)
// Use for consistent primary/secondary actions across the app.

struct ActionButton: View {
    @Environment(\.colorScheme) private var colorScheme

    var title: String
    var icon: String? = nil  // SF Symbol name
    var action: () -> Void
    var isDisabled: Bool = false
    var help: String? = nil
    var style: Style = .primary

    enum Style {
        case primary   // textPrimary, surfaceMuted
        case secondary // textSecondary, surfaceMuted.opacity(0.7)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(style == .primary ? CursorTheme.textPrimary(for: colorScheme) : CursorTheme.textSecondary(for: colorScheme))
            .padding(.horizontal, CursorTheme.paddingCard)
            .padding(.vertical, CursorTheme.spaceS)
            .background(backgroundFill, in: Capsule())
            .overlay(Capsule().stroke(CursorTheme.border(for: colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .modifier(OptionalHelpModifier(help: help))
    }

    private var backgroundFill: Color {
        switch style {
        case .primary: return CursorTheme.surfaceMuted(for: colorScheme)
        case .secondary: return CursorTheme.surfaceMuted(for: colorScheme).opacity(0.7)
        }
    }
}

// MARK: - Optional tooltip (apply .help only when non-empty)

private struct OptionalHelpModifier: ViewModifier {
    var help: String?

    func body(content: Content) -> some View {
        if let help, !help.isEmpty {
            content.help(help)
        } else {
            content
        }
    }
}
