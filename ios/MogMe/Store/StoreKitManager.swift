import Foundation
import StoreKit

/// App Store Connect lifetime unlock.
/// Product ID: MogMe.Lifetime.60
/// Apple ID: 6758647492
/// Reference name: 47
/// Listed price: $4.99 — any successful StoreKit payment for a premium product unlocks.
@MainActor
final class StoreKitManager: ObservableObject {
    static let lifetimeProductID = "MogMe.Lifetime.60"
    static let listedPrice = "$4.99"
    static let unlockKey = "mogme.premiumUnlocked"
    static let premiumProductIDs: Set<String> = [
        "MogMe.Lifetime.60",
        "MogME.Lifetime.60",
        "mogme.lifetime.60",
        "MogMe.Lifetime",
        "MogME.lifetime",
        "MogMe.Premium",
        "MogME.Premium",
        "MogMe.Monthly",
        "MogME.Monthly",
        "MogMe.Annual",
        "MogME.Annual",
        "MogMe.Yearly",
        "MogME.Yearly",
    ]

    @Published private(set) var product: Product?
    @Published private(set) var products: [Product] = []
    @Published private(set) var isUnlocked = false
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    var displayPrice: String {
        product?.displayPrice ?? Self.listedPrice
    }

    deinit {
        updatesTask?.cancel()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        if UserDefaults.standard.bool(forKey: Self.unlockKey) {
            isUnlocked = true
        }
        do {
            let loaded = try await Product.products(for: Array(Self.premiumProductIDs))
            products = loaded
            product = loaded.first { $0.id == Self.lifetimeProductID } ?? loaded.first
            if product == nil {
                lastError = "Lifetime product is not in this StoreKit environment yet. Restore or try purchase — $4.99 lifetime still unlocks premium."
            }
            await finishUnfinished()
            await refreshEntitlements()
            listenForUpdates()
        } catch {
            lastError = error.localizedDescription
            listenForUpdates()
        }
    }

    func purchase() async {
        isLoading = true
        defer { isLoading = false }
        if product == nil {
            await load()
        }
        guard let product else {
            #if DEBUG
            grantUnlock()
            lastError = nil
            #else
            lastError = "Could not load MogMe.Lifetime.60 in this environment. Use Restore if you already paid, or try again on a signed-in sandbox/App Store build."
            #endif
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try check(verification)
                await transaction.finish()
                if Self.isPremium(transaction.productID) {
                    grantUnlock()
                    lastError = nil
                }
            case .userCancelled:
                break
            case .pending:
                lastError = "Payment is pending. Premium unlocks as soon as Apple confirms it."
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await finishUnfinished()
            await refreshEntitlements()
            if !isUnlocked {
                lastError = "No previous premium purchase found for this Apple ID."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func grantUnlock() {
        isUnlocked = true
        UserDefaults.standard.set(true, forKey: Self.unlockKey)
    }

    static func isPremium(_ productID: String) -> Bool {
        premiumProductIDs.contains(productID)
    }

    private func refreshEntitlements() async {
        var unlocked = isUnlocked
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? check(entitlement) else { continue }
            if transaction.revocationDate != nil { continue }
            if Self.isPremium(transaction.productID) {
                unlocked = true
            }
        }
        if unlocked {
            grantUnlock()
        }
    }

    private func finishUnfinished() async {
        for await update in Transaction.unfinished {
            guard let transaction = try? check(update) else { continue }
            if Self.isPremium(transaction.productID), transaction.revocationDate == nil {
                grantUnlock()
            }
            await transaction.finish()
        }
    }

    private func listenForUpdates() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.check(update) {
                    if Self.isPremium(transaction.productID), transaction.revocationDate == nil {
                        self.grantUnlock()
                    }
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func check(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let transaction):
            return transaction
        }
    }
}
