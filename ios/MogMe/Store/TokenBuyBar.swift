import SwiftUI

/// The only token IAP: Tokens.Mogme — 100 tokens for $0.99.
struct TokenBuyBar: View {
    enum Style {
        case card
        case premium
    }

    @EnvironmentObject private var store: StoreKitManager
    @EnvironmentObject private var appState: AppState
    var style: Style = .card
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !compact {
                Text("AI tokens")
                    .font(.headline)
                    .foregroundStyle(titleColor)
                Text("Rizz, Companion, Wingman, and Mog-Off spend tokens. Lifetime does not make AI unlimited. The only pack is 100 tokens.")
                    .font(.footnote)
                    .foregroundStyle(mutedColor)
            }
            Text("\(store.purchasedTokens.formatted()) purchased on this iPhone")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentColor)
            Text(appState.aiQuota.tokenLine)
                .font(.caption)
                .foregroundStyle(mutedColor)

            Button {
                Task { await buy() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("100 AI tokens")
                            .font(.headline)
                            .foregroundStyle(titleColor)
                        Text("Tokens.Mogme · the only option")
                            .font(.caption)
                            .foregroundStyle(mutedColor)
                    }
                    Spacer()
                    Text(store.tokenPrice)
                        .font(.title3.bold())
                        .foregroundStyle(accentColor)
                }
                .padding(style == .premium ? 16 : 0)
                .background(style == .premium ? Color(red: 0.10, green: 0.14, blue: 0.13) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)
            .accessibilityIdentifier("buyTokensMogme")

            if appState.aiQuota.isExhausted {
                Text("Token pool is empty. Buy 100 tokens for \(store.tokenPrice).")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private var titleColor: Color { style == .premium ? .white : .white }
    private var mutedColor: Color { style == .premium ? .white.opacity(0.7) : MogTheme.muted }
    private var accentColor: Color {
        style == .premium ? Color(red: 0.97, green: 0.85, blue: 0.22) : MogTheme.gold
    }

    private func buy() async {
        let before = store.purchasedTokens
        await store.purchaseTokens()
        let gained = store.purchasedTokens - before
        guard gained > 0 else { return }
        await creditServer(gained)
    }

    private func creditServer(_ amount: Int) async {
        var url = appState.apiBaseURL
        url.append(path: "ai/credit")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "userKey": appState.userId ?? appState.handle,
            "tokens": amount,
        ])
        _ = try? await URLSession.shared.data(for: req)
        await appState.aiQuota.refresh(baseURL: appState.apiBaseURL, userKey: appState.userId ?? appState.handle)
        appState.aiQuota.syncPurchased(store.purchasedTokens)
    }
}
