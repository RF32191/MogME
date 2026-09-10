import Foundation
import StoreKit

/// App Store Connect lifetime unlock: MogMe.Lifetime.60 at $4.99 (changed Sep 9, 2026).
@MainActor
final class StoreKitManager: ObservableObject {
    static let lifetimeProductID = "MogMe.Lifetime.60"
    static let listedPrice = "$4.99"
    static let appleProductAppleID = "6758647492"
    static let referenceName = "47"
    static let storeDisplayName = "One-Time-Purchase"
    static let receiptUnlockKey = "mogme.premiumUnlocked.receipt"
    static let purchasedTokensKey = "mogme.purchasedAITokens"
    static let premiumProductIDs: Set<String> = [
        "MogMe.Lifetime.60",
        "MogME.Lifetime.60",
        "mogme.lifetime.60",
        "MogMe.Premium.Monthly",
        "MogMe.Premium.Annual",
        "MogME.Monthly",
        "MogMe.Monthly",
        "MogME.Annual",
        "MogMe.Annual",
        "MogMe.Yearly",
    ]
    static let tokenProductIDs: [String: Int] = [
        "MogMe.Tokens.2000": 2_000,
        "MogMe.Tokens.10000": 10_000,
        "MogMe.Tokens.40000": 40_000,
    ]

    @Published private(set) var product: Product?
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var annualProduct: Product?
    @Published private(set) var tokenProducts: [Product] = []
    @Published private(set) var products: [Product] = []
    @Published private(set) var isUnlocked = false
    @Published private(set) var isLoading = false
    @Published private(set) var purchasedTokens = 0
    @Published var lastError: String?
    @Published var showPaywall = false
    @Published var showOfferCode = false

    private var updatesTask: Task<Void, Never>?

    /// Lifetime is $4.99 after the Sep 9, 2026 App Store price change. Never show $59.99 / $60.
    var displayPrice: String {
        let live = product?.displayPrice ?? ""
        if live.contains("4.99") || live.contains("4,99") { return live }
        return Self.listedPrice
    }

    var monthlyPrice: String { monthlyProduct?.displayPrice ?? "$5.99" }
    var annualPrice: String { annualProduct?.displayPrice ?? "$29.99" }

    deinit {
        updatesTask?.cancel()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        UserDefaults.standard.removeObject(forKey: "mogme.premiumUnlocked")
        isUnlocked = UserDefaults.standard.bool(forKey: Self.receiptUnlockKey)
        purchasedTokens = UserDefaults.standard.integer(forKey: Self.purchasedTokensKey)
        do {
            let ids = Array(Self.premiumProductIDs) + Array(Self.tokenProductIDs.keys)
            let loaded = try await Product.products(for: ids)
            products = loaded
            product = loaded.first { $0.id == Self.lifetimeProductID }
                ?? loaded.first { Self.isLifetime($0.id) }
            monthlyProduct = loaded.first { Self.isMonthly($0.id) }
            annualProduct = loaded.first { Self.isAnnual($0.id) }
            tokenProducts = loaded
                .filter { Self.tokenProductIDs[$0.id] != nil }
                .sorted { (Self.tokenProductIDs[$0.id] ?? 0) < (Self.tokenProductIDs[$1.id] ?? 0) }
            await finishUnfinished()
            await refreshEntitlements()
            listenForUpdates()
        } catch {
            lastError = error.localizedDescription
            listenForUpdates()
        }
    }

    func purchase() async {
        await purchaseLifetime()
    }

    func purchaseLifetime() async {
        await buy(product) { transaction in
            if Self.isPremium(transaction.productID) {
                self.grantUnlock()
                self.lastError = nil
            }
            await transaction.finish()
        }
    }

    func purchaseMonthly() async {
        await buy(monthlyProduct) { transaction in
            if Self.isPremium(transaction.productID) {
                self.grantUnlock()
                self.lastError = nil
            }
            await transaction.finish()
        }
    }

    func purchaseAnnual() async {
        await buy(annualProduct) { transaction in
            if Self.isPremium(transaction.productID) {
                self.grantUnlock()
                self.lastError = nil
            }
            await transaction.finish()
        }
    }

    func purchaseTokens(_ pack: Product) async {
        let amount = Self.tokenProductIDs[pack.id] ?? 0
        await buy(pack) { transaction in
            if amount > 0 { self.creditTokens(amount) }
            await transaction.finish()
        }
    }

    func refreshAfterOffer() async {
        await finishUnfinished()
        await refreshEntitlements()
        if isUnlocked { lastError = nil }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await finishUnfinished()
            await refreshEntitlements()
            if !isUnlocked {
                lastError = "No previous lifetime purchase (\(Self.listedPrice)) found for this Apple ID."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func creditTokens(_ amount: Int) {
        purchasedTokens += max(0, amount)
        UserDefaults.standard.set(purchasedTokens, forKey: Self.purchasedTokensKey)
    }

    func spendPurchasedTokens(_ amount: Int) {
        purchasedTokens = max(0, purchasedTokens - max(0, amount))
        UserDefaults.standard.set(purchasedTokens, forKey: Self.purchasedTokensKey)
    }

    func grantUnlock() {
        isUnlocked = true
        UserDefaults.standard.set(true, forKey: Self.receiptUnlockKey)
    }

    static func isPremium(_ productID: String) -> Bool {
        isLifetime(productID) || isMonthly(productID) || isAnnual(productID)
    }

    static func isLifetime(_ productID: String) -> Bool {
        ["MogMe.Lifetime.60", "MogME.Lifetime.60", "mogme.lifetime.60"].contains(productID)
    }

    static func isMonthly(_ productID: String) -> Bool {
        productID.localizedCaseInsensitiveContains("month")
    }

    static func isAnnual(_ productID: String) -> Bool {
        productID.localizedCaseInsensitiveContains("annual")
            || productID.localizedCaseInsensitiveContains("year")
    }

    private func buy(_ product: Product?, onSuccess: (Transaction) async -> Void) async {
        isLoading = true
        defer { isLoading = false }
        if product == nil { await load() }
        guard let product else {
            lastError = "That App Store product is not in this StoreKit environment yet."
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try check(verification)
                await onSuccess(transaction)
            case .userCancelled:
                break
            case .pending:
                lastError = "Payment is pending. It unlocks as soon as Apple confirms it."
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
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
                    if let extra = Self.tokenProductIDs[transaction.productID] {
                        self.creditTokens(extra)
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
