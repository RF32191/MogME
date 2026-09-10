import SwiftUI

/// Big enough to see. Opens membership: plan, lifetime, and the $4.99 price.
struct CrownButton: View {
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        Button {
            store.showPaywall = true
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "crown.fill")
                    .font(.title2.weight(.bold))
                Text(StoreKitManager.listedPrice)
                    .font(.caption2.weight(.heavy))
            }
            .foregroundStyle(Color.black)
            .frame(width: 58, height: 58)
            .background(MogTheme.gold)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
            .shadow(color: MogTheme.gold.opacity(0.45), radius: 8, y: 2)
            .accessibilityLabel(
                store.isUnlocked
                    ? "Membership: lifetime \(StoreKitManager.listedPrice) is active"
                    : "Membership: lifetime \(StoreKitManager.listedPrice)"
            )
        }
        .buttonStyle(.plain)
    }
}

/// First-page membership card so the crown is in the content, not lost in the nav bar.
struct MembershipCrownCard: View {
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        Button {
            store.showPaywall = true
        } label: {
            MogCard {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 64, height: 64)
                        .background(MogTheme.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your membership")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MogTheme.muted)
                        Text(store.isUnlocked ? "Lifetime" : "Not subscribed")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Lifetime · \(StoreKitManager.listedPrice)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MogTheme.gold)
                        Text(store.isUnlocked
                             ? "Tap the crown to see what you own"
                             : "Tap the crown to see plans and price")
                            .font(.caption)
                            .foregroundStyle(MogTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(MogTheme.gold)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("homeMembershipCrown")
    }
}

extension View {
    func crownToolbar() -> some View {
        navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CrownButton()
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(MogTheme.card, for: .navigationBar)
    }
}
