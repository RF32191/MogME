import SwiftUI
import StoreKit

private let premiumGreen = Color(red: 0.04, green: 0.18, blue: 0.10)
private let premiumCard = Color(red: 0.10, green: 0.14, blue: 0.13)
private let premiumGold = Color(red: 0.97, green: 0.85, blue: 0.22)

struct PaywallView: View {
    @EnvironmentObject private var store: StoreKitManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            premiumGreen.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        Spacer()
                        Button {
                            store.showPaywall = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(10)
                        }
                    }
                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(premiumGold)
                        .shadow(color: premiumGold.opacity(0.55), radius: 16)
                        .padding(.top, 12)

                    VStack(spacing: 8) {
                        Text("Unlock MogME Premium")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        Text("Get full access to all features")
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    VStack(spacing: 10) {
                        planRow(
                            title: "MogME Lifetime",
                            subtitle: "Pay once, own forever",
                            price: StoreKitManager.listedPrice,
                            badge: "BEST VALUE",
                            selected: true
                        ) {
                            Task { await store.purchaseLifetime() }
                        }
                        planRow(
                            title: "MogME Monthly",
                            subtitle: "Billed monthly",
                            price: store.monthlyPrice,
                            badge: nil,
                            selected: false
                        ) {
                            Task { await store.purchaseMonthly() }
                        }
                        planRow(
                            title: "MogME Annual",
                            subtitle: "Save over 50%",
                            price: store.annualPrice,
                            badge: "MOST POPULAR",
                            selected: false
                        ) {
                            Task { await store.purchaseAnnual() }
                        }
                    }

                    tokensSection

                    Button {
                        store.showOfferCode = true
                    } label: {
                        Label("Redeem Offer Code", systemImage: "giftcard")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(premiumGold, lineWidth: 1.5)
                            )
                    }
                    .foregroundStyle(.white)

                    Button("Enter Code Manually") {
                        store.showOfferCode = true
                    }
                    .foregroundStyle(.white.opacity(0.85))

                    Text("Have a promo code? Tap above to redeem")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))

                    Button("Restore purchase") { Task { await store.restore() } }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))

                    if store.isUnlocked {
                        Text("Lifetime is active on this Apple ID")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(premiumGold)
                    }
                    if let err = store.lastError {
                        Text(err).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(22)
            }
        }
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        .offerCodeRedemption(isPresented: $store.showOfferCode) { _ in
            Task { await store.refreshAfterOffer() }
        }
        .task { await store.load() }
    }

    private var tokensSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Token packs", systemImage: "bag.fill")
                .font(.headline)
                .foregroundStyle(premiumGold)
            Text("\(appState.aiQuota.walletBalance.formatted()) tokens · 1 token = 1 game or AI message. \(AIQuota.dailyFreeTokens) free every day.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
            TokenPackRow()
            Text("Only option. No watch-an-ad. No Unlimited.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("crownTokenPacks")
    }

    private func planRow(
        title: String,
        subtitle: String,
        price: String,
        badge: String?,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(premiumGold)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(premiumGold.opacity(0.85))
                }
                Spacer()
                Text(price)
                    .font(.title2.bold())
            }
            .padding(16)
            .background(selected ? Color.white.opacity(0.14) : premiumCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(store.isLoading)
        .accessibilityIdentifier(title.contains("Lifetime") ? "lifetimePriceRow" : title)
        .accessibilityValue(price)
    }
}
