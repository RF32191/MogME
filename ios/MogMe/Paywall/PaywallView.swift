import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Membership")
                        .font(.largeTitle.bold())
                    Text("Lifetime is the App Store one-time purchase. Tap the crown anytime to see what you own.")
                        .foregroundStyle(MogTheme.muted)

                    MogCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: "crown.fill").foregroundStyle(MogTheme.gold)
                                Text(store.isUnlocked ? "You’re subscribed" : "Not subscribed")
                                    .font(.headline)
                                Spacer()
                                Text(store.isUnlocked ? "Lifetime" : "Free")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MogTheme.gold)
                            }
                            Text(StoreKitManager.storeDisplayName)
                                .font(.title2.bold())
                                .foregroundStyle(MogTheme.gold)
                            Text(store.displayPrice)
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(MogTheme.gold)
                            Text("Unlock all MogMe Premium features with one purchase.")
                                .font(.subheadline)
                            Text("Current App Store price for \(StoreKitManager.lifetimeProductID).")
                                .font(.footnote)
                                .foregroundStyle(MogTheme.muted)

                            row("Plan", store.isUnlocked ? "Lifetime unlock" : "None yet")
                            row("Display name", StoreKitManager.storeDisplayName)
                            row("Product ID", StoreKitManager.lifetimeProductID)
                            row("Reference", StoreKitManager.referenceName)
                            row("Apple ID", StoreKitManager.appleProductAppleID)
                            row("Price", store.displayPrice)
                            row("Status", store.isUnlocked ? "Unlocked on this Apple ID" : "Locked — buy or redeem an offer code")
                        }
                    }

                    MogCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lifetime includes").font(.headline)
                            Text("Japanese walking, interval GPS, diet photo analytics, wingman screenshot analysis, rizz trainer, companion, mog-off.")
                            Text("AI is token-based. Lifetime does not grant unlimited Wingman, Companion, or Rizz.")
                                .font(.subheadline)
                                .foregroundStyle(MogTheme.gold)
                        }
                    }

                    if !store.isUnlocked {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            Text(store.isLoading ? "Working…" : "Unlock lifetime \(store.displayPrice)")
                        }
                        .buttonStyle(GoldButtonStyle(enabled: !store.isLoading))
                    }

                    Button("Redeem offer code") {
                        store.showOfferCode = true
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(store.isLoading)

                    Button("Restore purchase") { Task { await store.restore() } }
                        .frame(maxWidth: .infinity)
                        .disabled(store.isLoading)

                    Text("Offer codes from App Store Connect (LIFETIMEACCESS, Lifetime Unlock) unlock the same \(StoreKitManager.lifetimeProductID) product.")
                        .font(.caption)
                        .foregroundStyle(MogTheme.muted)

                    if let err = store.lastError {
                        Text(err).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Membership")
        .offerCodeRedemption(isPresented: $store.showOfferCode) { _ in
            Task { await store.refreshAfterOffer() }
        }
        .task { await store.load() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(MogTheme.muted)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
