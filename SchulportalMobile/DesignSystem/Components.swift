import SwiftUI

/// The coloured subject pill from the userscript, as a real view.
struct SubjectChip: View {
    let subject: Subject
    var compact = false

    var body: some View {
        Text(subject.name)
            .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 7 : 10)
            .padding(.vertical, compact ? 2 : 3)
            .background(subject.color, in: .capsule)
            .lineLimit(1)
    }
}

/// Rounded, elevated container — the "card" look of the mobile restyle.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 38))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

/// Small inline banner for refresh problems — never blocks the cached content.
struct InlineErrorBanner: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let retry {
                    Button("Nochmal versuchen", action: retry)
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.12), in: .rect(cornerRadius: 12))
    }
}

extension View {
    /// Applies a subtle leading colour bar, as the homework blocks have.
    func subjectAccent(_ color: Color) -> some View {
        overlay(alignment: .leading) {
            Rectangle()
                .fill(color)
                .frame(width: 3)
                .clipShape(.rect(topLeadingRadius: 3, bottomLeadingRadius: 3))
        }
    }
}
