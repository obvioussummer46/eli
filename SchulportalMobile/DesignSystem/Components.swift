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

/// A password field with an eye: tap to see what was actually typed — the
/// difference between "wrong password" and "the keyboard capitalised the
/// first letter" on a phone.
///
/// Generic over the caller's focus value so the field takes part in the
/// screen's own next/go keyboard chain.
struct RevealablePasswordField<FocusValue: Hashable>: View {
    let titleKey: String
    @Binding var text: String
    var focus: FocusState<FocusValue?>.Binding
    let focusValue: FocusValue
    var onSubmit: () -> Void = {}

    @State private var isRevealed = false

    init(_ titleKey: String,
         text: Binding<String>,
         focus: FocusState<FocusValue?>.Binding,
         focusValue: FocusValue,
         onSubmit: @escaping () -> Void = {}) {
        self.titleKey = titleKey
        self._text = text
        self.focus = focus
        self.focusValue = focusValue
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                // Two different views, not one with a mode: SwiftUI has no
                // native reveal toggle, so the swap is the mechanism.
                if isRevealed {
                    TextField(titleKey, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(titleKey, text: $text)
                }
            }
            .textContentType(.password)
            .submitLabel(.go)
            .focused(focus, equals: focusValue)
            .onSubmit(onSubmit)

            Button {
                isRevealed.toggle()
                // Re-focus after SwiftUI has installed the swapped field —
                // in the same tick the new field does not exist yet and the
                // keyboard would drop.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    focus.wrappedValue = focusValue
                }
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Passwort verbergen" : "Passwort anzeigen")
        }
    }
}

/// Calm blue sibling of `InlineErrorBanner` — for facts about the account or
/// the school, where a retry button would promise something no retry can do.
struct InlineInfoBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.blue.opacity(0.10), in: .rect(cornerRadius: 12))
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
