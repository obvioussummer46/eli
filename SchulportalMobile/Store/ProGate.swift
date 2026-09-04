import SwiftUI

/// The small "Pro" tag next to a locked row, and the row that opens the
/// paywall. Locked features are visible on purpose — a setting that only
/// appears after paying can never be discovered.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor, in: .capsule)
    }
}

/// A `Form` row that either shows the unlocked content or a single tap to
/// the paywall — the caller decides the condition (Pro, widget pack, icon
/// pack) and this view only draws it.
struct LockedRow: View {
    let title: String
    var systemImage: String = "lock"
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                ProBadge()
            }
        }
        .tint(.primary)
    }
}

/// Presents the paywall as a sheet from anywhere; `.sheet(isPresented:)`
/// once per screen keeps the presentation predictable.
struct PaywallSheet: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            PaywallView()
        }
    }
}

extension View {
    func paywall(isPresented: Binding<Bool>) -> some View {
        modifier(PaywallSheet(isPresented: isPresented))
    }
}
