import SwiftUI
import WidgetKit

/// What a premium widget shows without the widget pack or Pro: a calm
/// placeholder naming the widget, and a tap that lands on the paywall.
/// Never an empty tile — an empty widget reads as broken, not as locked.
struct ProLockedView: View {
    @Environment(\.widgetFamily) private var family
    let title: String

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Image(systemName: "lock.fill")
            case .accessoryInline:
                Label("\(title) · \(Brand.proShort)", systemImage: "lock.fill")
            case .accessoryRectangular:
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.headline)
                        Text("In der App freischalten").font(.caption2)
                    }
                }
            default:
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.caption.weight(.semibold))
                    Text("Teil von \(Brand.pro) —\nin der App freischalten")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .widgetURL(WidgetLink.paywall)
    }
}

/// Wraps a premium widget's content: the real thing when unlocked, the
/// placeholder otherwise. The entry carries the flag so a purchase flips
/// every timeline at once via `EntitlementStore.save`.
struct PremiumGate<Content: View>: View {
    let entry: SnapshotEntry
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        if entry.unlocksPremium {
            content()
        } else {
            ProLockedView(title: title)
        }
    }
}
