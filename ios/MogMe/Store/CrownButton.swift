import SwiftUI

/// Big enough to see. Opens membership: plan, lifetime, and the live App Store price.
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
        VStack(spacing: 12) {
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
                            Text("Lifetime · \(StoreKitManager.listedPrice) · 100 tokens \(StoreKitManager.tokenListedPrice)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MogTheme.gold)
                            Text(store.isUnlocked
                                 ? "Tap the crown for membership. Tokens are \(StoreKitManager.tokenListedPrice) for 100."
                                 : "Tap the crown for \(StoreKitManager.listedPrice) lifetime and 100 tokens.")
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

            MogCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Token packs", systemImage: "bag.fill")
                        .font(.headline)
                        .foregroundStyle(MogTheme.gold)
                    Text("1 token = 1 game or AI message. \(AIQuota.dailyFreeTokens) free every day.")
                        .font(.caption)
                        .foregroundStyle(MogTheme.muted)
                    TokenPackRow()
                }
            }
        }
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
