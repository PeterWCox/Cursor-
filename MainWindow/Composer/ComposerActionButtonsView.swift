import SwiftUI

// MARK: - Composer action buttons (context indicator, Summarize) — same row as pickers

struct ComposerActionButtonsView: View {
    var hasContext: Bool
    var isRunning: Bool
    /// Context token usage for the small progress indicator; (used, limit). Pass (0, 0) to hide.
    var contextUsed: Int = 0
    var contextLimit: Int = 0
    var onSummarize: () -> Void

    private var contextFraction: Double {
        guard contextLimit > 0 else { return 0 }
        return min(1, Double(contextUsed) / Double(contextLimit))
    }

    var body: some View {
        HStack(spacing: 10) {
            Spacer()

            if contextLimit > 0 {
                contextProgressCircle
            }

            Button(action: onSummarize) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.compress.vertical")
                    Text("Summarize")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CursorTheme.brandAmber)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    CursorTheme.brandAmber.opacity(0.18),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(CursorTheme.brandAmber.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isRunning)
        }
    }

    private var contextProgressCircle: some View {
        let usedK = contextUsed / 1000
        let limitK = contextLimit / 1000
        let pct = contextLimit > 0 ? Int(round(contextFraction * 100)) : 0
        let tooltip = "~\(usedK)k / \(limitK)k tokens (\(pct)% used)"
        return ZStack {
            Circle()
                .stroke(CursorTheme.surfaceMuted, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: contextFraction)
                .stroke(
                    contextFraction > 0.85 ? CursorTheme.brandAmber : CursorTheme.brandBlue,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
        .help(tooltip)
    }
}
