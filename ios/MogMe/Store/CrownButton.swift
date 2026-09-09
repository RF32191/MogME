import SwiftUI

/// Always visible. Opens membership so you can see lifetime status and the $4.99 price.
struct CrownButton: View {
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        Button {
            store.showPaywall = true
        } label: {
            VStack(spacing: 1) {
                Image(systemName: store.isUnlocked ? "crown.fill" : "crown")
                    .font(.title3)
                Text(StoreKitManager.listedPrice)
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(MogTheme.gold)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .accessibilityLabel(
                store.isUnlocked
                    ? "Membership: lifetime \(StoreKitManager.listedPrice) is active"
                    : "Membership: lifetime \(StoreKitManager.listedPrice)"
            )
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
