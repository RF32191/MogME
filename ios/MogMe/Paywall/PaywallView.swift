import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("MogMe Lifetime")
                    .font(.largeTitle.bold())
                Text("App Store Connect product MogMe.Lifetime.60 (Apple ID 6758647492). The price on this screen is whatever Apple is serving — it is no longer hardcoded at $4.99.")
                    .foregroundStyle(MogTheme.muted)
                MogCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("One-time unlock").font(.headline)
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
                .buttonStyle(GoldButtonStyle(enabled: !store.isLoading && store.product != nil))
                Button("Restore purchase") { Task { await store.restore() } }
                    .frame(maxWidth: .infinity)
                if let err = store.lastError {
                    Text(err).font(.footnote).foregroundStyle(.red)
                }
                if store.isUnlocked {
                    Text("You're in. Lifetime is active on this Apple ID.")
                        .foregroundStyle(MogTheme.gold)
                }
                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("Unlock")
    }
}
