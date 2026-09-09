import Foundation
import StoreKit

/// App Store Connect lifetime unlock.
/// Product ID: MogMe.Lifetime.60 (the "$60" SKU) is sold at $4.99.
@MainActor
final class StoreKitManager: ObservableObject {
    static let lifetimeProductID = "MogMe.Lifetime.60"
    static let listedPrice = "$4.99"
    static let receiptUnlockKey = "mogme.premiumUnlocked.receipt"
    static let premiumProductIDs: Set<String> = [
        "MogMe.Lifetime.60",
        "MogME.Lifetime.60",
        "mogme.lifetime.60",
    ]

    @Published private(set) var product: Product?
    @Published private(set) var products: [Product] = []
    @Published private(set) var isUnlocked = false
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    @Published var showPaywall = false

    private var updatesTask: Task<Void, Never>?

    /// Always advertise $4.99 for the Lifetime.60 SKU. StoreKit's live price is
    /// used only if Apple actually returns that same $4.99 product.
    var displayPrice: String { Self.listedPrice }

    deinit {
        updatesTask?.cancel()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        UserDefaults.standard.removeObject(forKey: "mogme.premiumUnlocked")
        isUnlocked = UserDefaults.standard.bool(forKey: Self.receiptUnlockKey)
        do {
            let loaded = try await Product.products(for: Array(Self.premiumProductIDs))
            products = loaded
            product = loaded.first { $0.id == Self.lifetimeProductID } ?? loaded.first
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
        if product == nil { await load() }
        guard let product else {
            lastError = "MogMe.Lifetime.60 ($4.99) is not in this StoreKit environment. Open the scheme’s Products.storekit file, or Restore a real receipt."
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
                lastError = "No previous $4.99 lifetime purchase found for this Apple ID."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func grantUnlock() {
        isUnlocked = true
        UserDefaults.standard.set(true, forKey: Self.receiptUnlockKey)
    }

    static func isPremium(_ productID: String) -> Bool {
        premiumProductIDs.contains(productID)
    }

    private func refreshEntitlements() async {
        var unlocked = false
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? check(entitlement) else { continue }
            if transaction.revocationDate != nil { continue }
            if Self.isPremium(transaction.productID) {
                unlocked = true
            }
        }
        if unlocked {
            grantUnlock()
        } else {
            isUnlocked = false
            UserDefaults.standard.set(false, forKey: Self.receiptUnlockKey)
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
