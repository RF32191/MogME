import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreKitManager
    @EnvironmentObject private var meals: MealStore

    var body: some View {
        NavigationStack {
            ZStack {
                MogTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MogMe").font(.largeTitle.bold())
                                Text("Looks, fitness, diet, and social.")
                                    .foregroundStyle(MogTheme.muted)
                            }
                            Spacer()
                            CrownButton()
                        }

                        MembershipCrownCard()

                        tokenWallet

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            quick("Diet", "\(Int(meals.todayCalories)) kcal today", .diet, "fork.knife")
                            quick("Japanese walk", "3 / 3 intervals", .train, "figure.walk")
                            quick("Wingman", appState.aiQuota.tokenLine, .social, "bubble.left.and.text.bubble.right.fill")
                            quick("Rizz Trainer", "Token-metered", .play, "flame.fill")
                        }

                        MogCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Handle").font(.headline)
                                TextField("mogger", text: Binding(
                                    get: { appState.handle },
                                    set: { appState.setHandle($0) }
                                ))
                                .textFieldStyle(.roundedBorder)
                                Text("Used for mog-off sign-in and your daily AI token wallet.")
                                    .font(.caption)
                                    .foregroundStyle(MogTheme.muted)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Home")
            .crownToolbar()
            .task {
                await appState.aiQuota.refresh(
                    baseURL: appState.apiBaseURL,
                    userKey: appState.userId ?? appState.handle
                )
            }
        }
    }

    private var tokenWallet: some View {
        MogCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("AI token wallet").font(.headline)
                Text("\(appState.aiQuota.snapshot.tokensRemaining.formatted()) tokens left")
                    .font(.title2.bold())
                    .foregroundStyle(MogTheme.gold)
                ProgressView(
                    value: Double(max(0, appState.aiQuota.snapshot.dailyTokenCap - appState.aiQuota.snapshot.tokensRemaining)),
                    total: Double(max(1, appState.aiQuota.snapshot.dailyTokenCap))
                )
                .tint(MogTheme.gold)
                Text(appState.aiQuota.walletDetail)
                    .font(.footnote)
                    .foregroundStyle(MogTheme.muted)
                Text("Wingman, Companion, and Rizz spend tokens. Lifetime does not make AI unlimited.")
                    .font(.caption)
                    .foregroundStyle(MogTheme.muted)
                if appState.aiQuota.isExhausted {
                    Text("Token pool is empty for today.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func quick(_ title: String, _ subtitle: String, _ tab: AppState.Tab, _ icon: String) -> some View {
        Button {
            appState.tab = tab
        } label: {
            MogCard {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: icon).foregroundStyle(MogTheme.gold)
                    Text(title).font(.headline).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(MogTheme.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
