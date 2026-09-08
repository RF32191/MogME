import Foundation
import StoreKit

/// App Store Connect lifetime unlock.
/// Product ID: MogMe.Lifetime.60
/// Apple ID: 6758647492
/// Reference name: 47
/// Status: Approved (custom price set in App Store Connect — do not hardcode $4.99).
@MainActor
final class StoreKitManager: ObservableObject {
    static let lifetimeProductID = "MogMe.Lifetime.60"

    @Published private(set) var product: Product?
    @Published private(set) var isUnlocked = false
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    /// Display the live App Store price. Falls back only when StoreKit has not loaded yet.
    var displayPrice: String {
        product?.displayPrice ?? "…"
    }

    deinit {
        updatesTask?.cancel()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.lifetimeProductID])
            product = products.first
            await refreshEntitlements()
            listenForUpdates()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product else {
            lastError = "Lifetime unlock is still loading. Try again in a moment."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try check(verification)
                await transaction.finish()
                isUnlocked = true
                lastError = nil
            case .userCancelled, .pending:
                break
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
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var unlocked = false
        for await entitlement in Transaction.currentEntitlements {
            if let transaction = try? check(entitlement),
               transaction.productID == Self.lifetimeProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isUnlocked = unlocked
    }

    private func listenForUpdates() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.check(update) {
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
