import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("MogMe Lifetime")
                    .font(.largeTitle.bold())
                Text("MogMe.Lifetime.60 is the lifetime SKU. It is \(StoreKitManager.listedPrice) — not $60. Apple Pay, card, and Restore all unlock the same premium.")
                    .foregroundStyle(MogTheme.muted)
                MogCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lifetime").font(.headline)
                        Text(store.displayPrice)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(MogTheme.gold)
                        Text("Japanese walking, interval GPS, diet log, wingman, rizz trainer, companion, mog-off.")
                            .font(.subheadline)
                            .foregroundStyle(MogTheme.muted)
                    }
                }
                Button {
                    Task { await store.purchase() }
                } label: {
                    Text(store.isLoading ? "Working…" : "Unlock \(store.displayPrice)")
                }
                .buttonStyle(GoldButtonStyle(enabled: !store.isLoading))
                Button("Restore purchase") { Task { await store.restore() } }
                    .frame(maxWidth: .infinity)
                    .disabled(store.isLoading)
                if store.product == nil, !store.isUnlocked {
                    Text("If the $4.99 product is missing, enable Products.storekit on the MogMe scheme (Debug) or Restore a real App Store receipt.")
                        .font(.footnote)
                        .foregroundStyle(MogTheme.muted)
                }
                if let err = store.lastError {
                    Text(err).font(.footnote).foregroundStyle(.red)
                }
                if store.isUnlocked {
                    Text("Premium is unlocked on this device.")
                        .foregroundStyle(MogTheme.gold)
                }
                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Unlock")
        .task { await store.load() }
    }
}
