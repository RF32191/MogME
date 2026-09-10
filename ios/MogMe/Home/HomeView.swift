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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Tokens").font(.headline)
                    Spacer()
                    Button("Open") { store.showTokens = true }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MogTheme.gold)
                }
                Text("\(appState.aiQuota.walletBalance.formatted())")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(MogTheme.gold)
                Text("1 token = 1 game or AI message")
                    .font(.subheadline)
                    .foregroundStyle(MogTheme.muted)
                Text("You get \(AIQuota.dailyFreeTokens) free every day.")
                    .font(.footnote)
                    .foregroundStyle(MogTheme.muted)
                TokenPackRow()
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
