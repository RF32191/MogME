import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        TabView(selection: $appState.tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "sparkles") }
                .tag(AppState.Tab.home)
            DietView()
                .tabItem { Label("Diet", systemImage: "fork.knife") }
                .tag(AppState.Tab.diet)
            TrainView()
                .tabItem { Label("Train", systemImage: "figure.walk") }
                .tag(AppState.Tab.train)
            SocialView()
                .tabItem { Label("Social", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppState.Tab.social)
            PlayHubView()
                .tabItem { Label("Play", systemImage: "gamecontroller.fill") }
                .tag(AppState.Tab.play)
        }
        .tint(MogTheme.gold)
        .sheet(isPresented: $store.showPaywall) {
            NavigationStack {
                PaywallView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { store.showPaywall = false }
                        }
                    }
            }
        }
    }
}

struct PlayHubView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                MogTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        NavigationLink { RizzTrainerView() } label: {
                            hubRow("Rizz Trainer", "Practice openers, numbers, and dates with live coaching.", "flame.fill")
                        }
                        NavigationLink { CompanionView() } label: {
                            hubRow("Companion", "Ongoing on-device persona chat. History never leaves your phone except the last few turns.", "heart.fill")
                        }
                        NavigationLink { MogOffView() } label: {
                            hubRow("Mog-Off", "Queue for face, cognition, reflex, punch, and rizz rounds.", "trophy.fill")
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Play")
            .crownToolbar()
        }
    }

    private func hubRow(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        MogCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(MogTheme.gold)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(MogTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(MogTheme.muted)
            }
        }
    }
}
