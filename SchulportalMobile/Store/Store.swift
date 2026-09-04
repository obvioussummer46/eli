import Foundation
import Observation
import OSLog
import StoreKit

/// StoreKit 2, reduced to what the app needs: load the products, buy one,
/// restore, and keep `Entitlements` in the App Group current so the widgets
/// see the same truth as the app.
///
/// No receipt server, no accounts: `Transaction.currentEntitlements` is
/// the source of truth for everything non-consumable (Family Sharing and
/// refunds included), and the tip jar's thank-you state is the one flag
/// remembered locally because consumables leave no entitlement behind.
@MainActor
@Observable
final class Store {
    private(set) var products: [Product] = []
    private(set) var entitlements = EntitlementStore.load()
    private(set) var isLoadingProducts = false
    private(set) var purchaseInFlight: ProductID?
    /// The last thing that went wrong, for the paywall to show. StoreKit's
    /// own sheets already cover cancellation and payment problems, so this
    /// is only for "products could not be loaded" and verification failures.
    private(set) var lastErrorMessage: String?
    /// Set briefly after a successful tip, for the thank-you animation.
    private(set) var justTipped = false

    @ObservationIgnored private var updatesListener: Task<Void, Never>?
    private let logger = Logger(subsystem: "de.schulportalmobile.app", category: "store")

    /// Call once at launch. Listening to `Transaction.updates` from the start
    /// is what makes Ask to Buy approvals, family purchases and refunds land
    /// without the user doing anything.
    func start() {
        guard updatesListener == nil else { return }
        updatesListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(result)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Products

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            // App Store Connect returns them in arbitrary order; keep ours.
            let order = Dictionary(uniqueKeysWithValues: ProductID.allCases.enumerated().map { ($1.rawValue, $0) })
            products = loaded.sorted { (order[$0.id] ?? 99) < (order[$1.id] ?? 99) }
            lastErrorMessage = nil
        } catch {
            logger.error("Produkte konnten nicht geladen werden: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = "Die Angebote konnten gerade nicht geladen werden. Bitte später noch einmal versuchen."
        }
    }

    func product(_ id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    /// "7 Tage kostenlos" when the yearly plan carries a free trial the user
    /// is still eligible for, otherwise nil. Eligibility is per Apple ID and
    /// must be asked, not assumed — showing a trial someone already used is
    /// exactly the kind of thing that gets a paywall rejected.
    func trialLabel(for id: ProductID) async -> String? {
        guard let product = product(id), let subscription = product.subscription,
              let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        guard await subscription.isEligibleForIntroOffer else { return nil }
        let value = offer.period.value
        switch offer.period.unit {
        case .day: return "\(value) Tage kostenlos testen"
        case .week: return value == 1 ? "1 Woche kostenlos testen" : "\(value) Wochen kostenlos testen"
        case .month: return value == 1 ? "1 Monat kostenlos testen" : "\(value) Monate kostenlos testen"
        case .year: return "\(value) Jahr kostenlos testen"
        @unknown default: return nil
        }
    }

    // MARK: - Purchasing

    @discardableResult
    func purchase(_ id: ProductID) async -> Bool {
        guard purchaseInFlight == nil else { return false }
        if products.isEmpty { await loadProducts() }
        guard let product = product(id) else {
            lastErrorMessage = "Dieses Angebot ist gerade nicht verfügbar."
            return false
        }
        purchaseInFlight = id
        defer { purchaseInFlight = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                if id.isTip {
                    markTipped()
                }
                await transaction.finish()
                await refreshEntitlements()
                lastErrorMessage = nil
                return true
            case .userCancelled:
                return false
            case .pending:
                // Ask to Buy — the parent approves later, `Transaction.updates`
                // delivers it. Nothing to show; the sheet already said so.
                return false
            @unknown default:
                return false
            }
        } catch {
            logger.error("Kauf fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = "Der Kauf konnte nicht abgeschlossen werden. Es wurde nichts berechnet."
            return false
        }
    }

    /// "Käufe wiederherstellen" — required by review, and the only way a new
    /// device learns about a lifetime purchase before its first launch sync.
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            logger.notice("AppStore.sync: \(error.localizedDescription, privacy: .public)")
        }
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var fresh = Entitlements()
        fresh.hasTipped = entitlements.hasTipped
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            apply(transaction.productID, to: &fresh)
        }
        fresh.updatedAt = Date()
        commit(fresh)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if let id = ProductID(rawValue: transaction.productID), id.isTip, transaction.revocationDate == nil {
            markTipped()
        }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func apply(_ productID: String, to entitlements: inout Entitlements) {
        guard let id = ProductID(rawValue: productID) else { return }
        if id.isPro { entitlements.isPro = true }
        if id == .widgetPack { entitlements.hasWidgetPack = true }
        if let pack = id.iconPackID { entitlements.ownedIconPacks.insert(pack) }
    }

    private func markTipped() {
        var updated = entitlements
        updated.hasTipped = true
        commit(updated)
        justTipped = true
        Task {
            try? await Task.sleep(for: .seconds(4))
            justTipped = false
        }
    }

    private func commit(_ fresh: Entitlements) {
        guard fresh != entitlements else { return }
        entitlements = fresh
        EntitlementStore.save(fresh)
        // A lapsed Pro must not keep custom reminder times alive; rescheduling
        // re-reads the entitlement and falls back to the defaults on its own.
        if Settings.digestNotificationsEnabled {
            NotificationScheduler.rescheduleDigest()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }
}

/// Links the paywall must carry (Guideline 3.1.2). Replace before the
/// first paid build goes to review — both must resolve.
enum StoreLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://github.com/obvioussummer46/eli/blob/main/Docs/DATENSCHUTZ.md")!
}
