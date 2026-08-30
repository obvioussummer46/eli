import SwiftUI

/// The balance, big, at the top of the tab — the number the tab exists for.
struct MensaBalanceCard: View {
    @Environment(MensaModel.self) private var mensa

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Guthaben")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(mensa.account.balanceDisplay)
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(balanceColor)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    if mensa.isLoading {
                        ProgressView()
                    }
                }

                if !mensa.account.username.isEmpty {
                    Label(mensa.account.username, systemImage: "person.crop.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isLow {
                    Label("Das Guthaben wird knapp — bitte aufladen.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                NavigationLink {
                    MensaStatementView()
                } label: {
                    Label("Kontoauszug", systemImage: "list.bullet.rectangle")
                        .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private var isLow: Bool {
        mensa.account.isLow(threshold: mensa.statement.lowBalanceThreshold ?? 15)
    }

    private var balanceColor: Color {
        guard let balance = mensa.account.balance else { return .primary }
        if balance < 0 { return .red }
        return isLow ? .orange : .green
    }
}

/// One day in the horizontal picker: weekday, date, and a dot when a menu is
/// ordered.
struct MensaDayChip: View {
    let day: MenuDay
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(day.id)
                .font(.caption.weight(.bold))
            Text(dayLabel)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            Circle()
                .fill(day.orderedOptionID == nil ? Color.clear : (isSelected ? Color.white : Color.accentColor))
                .frame(width: 5, height: 5)
        }
        .frame(width: 58)
        .padding(.vertical, 9)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(background, in: .rect(cornerRadius: 12))
        .overlay {
            if isToday && !isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
            }
        }
        .contentShape(.rect)
    }

    private var background: Color {
        isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground)
    }

    private var dayLabel: String {
        guard let date = day.date else { return "—" }
        return GermanDate.dayMonth.string(from: date)
    }
}

/// One dish.
struct MensaMenuCard: View {
    let option: MenuOption
    let isOrdered: Bool
    let isLocked: Bool

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Text(option.title)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !option.priceText.isEmpty {
                        Text(option.priceText)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                if !option.text.isEmpty {
                    Text(option.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if isOrdered {
                        Label("Bestellt", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                    if option.isCertified {
                        Text("DGE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: .capsule)
                    }
                    Spacer(minLength: 0)
                    if !option.allergenCodes.isEmpty {
                        Text(option.allergenCodes)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .overlay {
            if isOrdered {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.green, lineWidth: 2)
            }
        }
        .opacity(isLocked && !isOrdered ? 0.6 : 1)
        // The spelled-out allergens are long; a tap is a better place for them
        // than the card.
        .accessibilityHint(option.allergenText)
        .contextMenu {
            if !option.allergenText.isEmpty {
                Text(option.allergenText)
            }
        }
    }
}

/// The one line that explains why nothing here is tappable.
struct MensaOrderHint: View {
    let day: MenuDay

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var message: String {
        if day.orderedOption != nil {
            return "Bestellt. Ändern geht nur auf menuebestellung.de."
        }
        if day.isLocked {
            return "Für diesen Tag ist die Bestellfrist abgelaufen."
        }
        return "Nichts bestellt. Bestellen geht nur auf menuebestellung.de."
    }
}
