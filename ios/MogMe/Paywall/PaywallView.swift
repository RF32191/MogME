import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Membership")
                        .font(.largeTitle.bold())
                    Text("The crown stays on every screen. Open it anytime to see what you own.")
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
                            Text("Lifetime")
                                .font(.title2.bold())
                                .foregroundStyle(MogTheme.gold)
                            Text(StoreKitManager.listedPrice)
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(MogTheme.gold)
                            Text("New listed price for MogMe.Lifetime.60 — not $60.")
                                .font(.footnote)
                                .foregroundStyle(MogTheme.muted)

                            row("Plan", store.isUnlocked ? "Lifetime unlock" : "None yet")
                            row("Product", StoreKitManager.lifetimeProductID)
                            row("Price", StoreKitManager.listedPrice)
                            row("Apple ID", "6758647492")
                            row("Status", store.isUnlocked ? "Unlocked on this Apple ID" : "Locked — tap Unlock lifetime")
                        }
                    }

                    MogCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lifetime includes").font(.headline)
                            Text("Japanese walking, interval GPS, diet photo analytics, wingman screenshot analysis, rizz trainer, companion, mog-off.")
                            Text("AI is token-based. Lifetime does not grant unlimited Wingman, Companion, or Rizz. Those spend the daily token wallet on Home.")
                                .font(.subheadline)
                                .foregroundStyle(MogTheme.gold)
                                .font(.subheadline)
                                .foregroundStyle(MogTheme.muted)
                        }
                    }

                    if !store.isUnlocked {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            Text(store.isLoading ? "Working…" : "Unlock lifetime \(StoreKitManager.listedPrice)")
                        }
                        .buttonStyle(GoldButtonStyle(enabled: !store.isLoading))
                    }

                    Button("Restore purchase") { Task { await store.restore() } }
                        .frame(maxWidth: .infinity)
                        .disabled(store.isLoading)

                    if let err = store.lastError {
                        Text(err).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Membership")
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
