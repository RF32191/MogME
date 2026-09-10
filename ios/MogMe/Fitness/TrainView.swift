import SwiftUI

struct TrainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var openWalk = false
    @State private var openCardio = false

    var body: some View {
        NavigationStack {
            ZStack {
                MogTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        if appState.walkRuntime.isRunning {
                            liveBanner("Japanese walk is still tracking", tab: { openWalk = true })
                        }
                        if appState.cardioRuntime.isRunning {
                            liveBanner("Interval cardio is still tracking", tab: { openCardio = true })
                        }
                        NavigationLink {
                            JapaneseWalkingView()
                        } label: {
                            workoutCard(
                                "Japanese Walking",
                                "3 min brisk / 3 min easy. Keeps GPS and intervals going if you leave the app.",
                                "figure.walk.motion"
                            )
                        }
                        NavigationLink {
                            IntervalCardioView()
                        } label: {
                            workoutCard(
                                "Interval Cardio",
                                "Work/rest GPS on a background thread. Completes even if you lock the phone.",
                                "figure.run"
                            )
                        }

                        if !appState.workouts.items.isEmpty {
                            Text("Recent sessions")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                            ForEach(appState.workouts.items.prefix(8)) { item in
                                MogCard {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.kind.title).font(.headline)
                                        Text(item.startedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(MogTheme.muted)
                                        Text(String(format: "%.2f km · %d kcal · %d min", item.distanceMeters / 1000, Int(item.calories), item.elapsedSec / 60))
                                            .font(.subheadline)
                                            .foregroundStyle(MogTheme.gold)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Train")
            .crownToolbar()
            .navigationDestination(isPresented: $openWalk) {
                JapaneseWalkingView()
            }
            .navigationDestination(isPresented: $openCardio) {
                IntervalCardioView()
            }
            .onAppear {
                if appState.pendingWalkStart { openWalk = true }
                if appState.pendingCardioStart { openCardio = true }
            }
            .onReceive(appState.walkRuntime.objectWillChange) { _ in }
            .onReceive(appState.cardioRuntime.objectWillChange) { _ in }
        }
    }

    private func liveBanner(_ title: String, tab: @escaping () -> Void) -> some View {
        Button(action: tab) {
            MogCard {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(MogTheme.gold)
                    Text(title).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("Open").font(.caption).foregroundStyle(MogTheme.gold)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func workoutCard(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        MogCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).font(.title).foregroundStyle(MogTheme.gold)
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
