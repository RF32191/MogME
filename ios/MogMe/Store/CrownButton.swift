import SwiftUI

/// Visible whenever lifetime is not unlocked. Always advertises $4.99 for MogMe.Lifetime.60.
struct CrownButton: View {
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        if !store.isUnlocked {
            NavigationLink {
                PaywallView()
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                    Text(StoreKitManager.listedPrice)
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(MogTheme.gold)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .accessibilityLabel("Unlock lifetime for \(StoreKitManager.listedPrice)")
            }
        }
    }
}

extension View {
    func crownToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CrownButton()
            }
        }
    }
}
