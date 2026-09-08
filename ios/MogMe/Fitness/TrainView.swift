import SwiftUI

struct TrainView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var history = WorkoutHistoryStore()
    @State private var openWalk = false
    @State private var openCardio = false

    var body: some View {
        NavigationStack {
            ZStack {
                MogTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        NavigationLink {
                            JapaneseWalkingView(history: history)
                        } label: {
                            workoutCard(
                                "Japanese Walking",
                                "3 min brisk / 3 min easy. Thread-safe GPS, pace, and route.",
                                "figure.walk.motion"
                            )
                        }
                        NavigationLink {
                            IntervalCardioView(history: history)
                        } label: {
                            workoutCard(
                                "Interval Cardio",
                                "Work/rest GPS session with filtered points so the map no longer jumps or crashes.",
                                "figure.run"
                            )
                        }

                        if !history.items.isEmpty {
                            Text("Recent sessions")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                            ForEach(history.items.prefix(8)) { item in
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
            .navigationDestination(isPresented: $openWalk) {
                JapaneseWalkingView(history: history)
            }
            .navigationDestination(isPresented: $openCardio) {
                IntervalCardioView(history: history)
            }
            .onAppear {
                if appState.pendingWalkStart { openWalk = true }
                if appState.pendingCardioStart { openCardio = true }
            }
        }
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
