import SwiftUI

private let tokenInk = Color.white
private let tokenMuted = Color.white.opacity(0.55)
private let tokenGold = Color(red: 0.97, green: 0.85, blue: 0.22)
private let tokenCard = Color(red: 0.12, green: 0.12, blue: 0.13)
private let tokenSheet = Color.black

/// Single IAP row: Tokens.Mogme — 100 tokens for $0.99. No other packs.
struct TokenPackRow: View {
    @EnvironmentObject private var store: StoreKitManager
    @EnvironmentObject private var appState: AppState
    var goldPrice: Bool = true

    var body: some View {
        Button {
            Task { await TokenPurchase.buy(store: store, appState: appState) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(tokenGold)
                    .frame(width: 28)
                Text("100 tokens")
                    .font(.headline)
                    .foregroundStyle(tokenInk)
                Spacer()
                Text(StoreKitManager.tokenListedPrice)
                    .font(.title3.bold())
                    .foregroundStyle(goldPrice ? tokenGold : tokenInk)
            }
            .padding(18)
            .background(tokenCard)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(store.isLoading)
        .accessibilityIdentifier("buyTokensMogme")
    }
}

/// Live-app Tokens sheet: balance, 5 free/day, one $0.99 pack. No ads. No Unlimited.
struct TokensStoreView: View {
    @EnvironmentObject private var store: StoreKitManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            tokenSheet.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(tokenGold)
                    Spacer()
                    Text("Tokens")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button("Done") {
                        store.showTokens = false
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(tokenGold)
                    .clipShape(Capsule())
                }

                VStack(spacing: 8) {
                    Text("\(appState.aiQuota.walletBalance.formatted())")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(tokenInk)
                    Text("tokens · 1 token = 1 game or AI message")
                        .font(.subheadline)
                        .foregroundStyle(tokenMuted)
                    Text("You get \(AIQuota.dailyFreeTokens) free every day.")
                        .font(.subheadline)
                        .foregroundStyle(tokenMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(tokenCard)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Label("Token packs", systemImage: "bag.fill")
                        .font(.headline)
                        .foregroundStyle(tokenGold)
                    TokenPackRow()
                    Text("This is the only pack. No ads. No Unlimited.")
                        .font(.footnote)
                        .foregroundStyle(tokenMuted)
                }

                if let err = store.lastError {
                    Text(err).font(.footnote).foregroundStyle(.red)
                }
                Spacer()
            }
            .padding(20)
        }
        .foregroundStyle(tokenInk)
        .task { await store.load() }
    }
}

/// Compact buy control used under Rizz, Companion, Wingman, and Mog-Off.
struct TokenBuyBar: View {
    @EnvironmentObject private var store: StoreKitManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tokens")
                    .font(.headline)
                Spacer()
                Button("See wallet") {
                    store.showTokens = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(MogTheme.gold)
            }
            Text("\(appState.aiQuota.walletBalance.formatted()) left · 1 token = 1 AI message · \(AIQuota.dailyFreeTokens) free / day")
                .font(.caption)
                .foregroundStyle(MogTheme.muted)
            TokenPackRow()
            if appState.aiQuota.isExhausted {
                Text("Token pool is empty. Buy 100 tokens for \(StoreKitManager.tokenListedPrice).")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }
}

enum TokenPurchase {
    @MainActor
    static func buy(store: StoreKitManager, appState: AppState) async {
        let before = store.purchasedTokens
        await store.purchaseTokens()
        let gained = store.purchasedTokens - before
        guard gained > 0 else { return }
        var url = appState.apiBaseURL
        url.append(path: "ai/credit")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "userKey": appState.userId ?? appState.handle,
            "tokens": gained,
        ])
        _ = try? await URLSession.shared.data(for: req)
        await appState.aiQuota.refresh(baseURL: appState.apiBaseURL, userKey: appState.userId ?? appState.handle)
        appState.aiQuota.syncPurchased(store.purchasedTokens)
    }
}
