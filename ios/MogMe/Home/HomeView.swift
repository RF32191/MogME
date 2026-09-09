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
                        MogCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("MogMe").font(.largeTitle.bold())
                                Text("Looks, fitness, diet, and social — one lifestyle stack.")
                                    .foregroundStyle(MogTheme.muted)
                                Text(store.isUnlocked ? "Lifetime unlocked" : "Lifetime \(StoreKitManager.listedPrice)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MogTheme.gold)
                            }
                        }

                        if !store.isUnlocked {
                            Button { store.showPaywall = true } label: {
                                Label("Unlock lifetime \(StoreKitManager.listedPrice)", systemImage: "crown.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GoldButtonStyle())
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            quick("Diet", "\(Int(meals.todayCalories)) kcal today", .diet, "fork.knife")
                            quick("Japanese walk", "3 / 3 intervals", .train, "figure.walk")
                            quick("Wingman", "Coach a chat", .social, "bubble.left.and.text.bubble.right.fill")
                            quick("Rizz Trainer", "Practice a close", .play, "flame.fill")
                        }

                        MogCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Handle").font(.headline)
                                TextField("mogger", text: Binding(
                                    get: { appState.handle },
                                    set: { appState.setHandle($0) }
                                ))
                                .textFieldStyle(.roundedBorder)
                                Text("Used for mog-off sign-in and the wingman daily token budget.")
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
