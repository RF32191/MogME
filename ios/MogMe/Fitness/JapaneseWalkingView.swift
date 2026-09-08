import SwiftUI

struct JapaneseWalkingView: View {
    @ObservedObject var history: WorkoutHistoryStore
    @EnvironmentObject private var appState: AppState
    @StateObject private var gps = WorkoutLocationEngine()
    @State private var blocks = WorkoutPresets.japaneseWalking()
    @State private var index = 0
    @State private var remaining = 180
    @State private var running = false
    @State private var elapsed = 0
    @State private var burned = 0.0
    @State private var bodyKg = 75.0
    @State private var timer: Timer?

    var body: some View {
        workoutChrome(
            title: "Japanese Walking",
            subtitle: currentBlock.label,
            isHard: currentBlock.isHard
        )
        .onAppear {
            if appState.pendingWalkStart {
                appState.pendingWalkStart = false
                start()
            }
        }
        .onDisappear { stopTimerOnly() }
    }

    private var currentBlock: IntervalBlock {
        blocks[min(index, blocks.count - 1)]
    }

    private func workoutChrome(title: String, subtitle: String, isHard: Bool) -> some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 14) {
                WorkoutMapView(route: gps.route, isHard: isHard)
                    .frame(height: 220)
                MogCard {
                    VStack(spacing: 8) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.title2.bold()).foregroundStyle(isHard ? Color.orange : MogTheme.gold)
                        Text(clock(remaining)).font(.system(size: 48, weight: .bold, design: .rounded))
                        Text(gps.statusMessage).font(.caption).foregroundStyle(MogTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
                HStack {
                    stat("Distance", String(format: "%.2f km", gps.distanceMeters / 1000))
                    stat("Pace", paceString)
                    stat("kcal", String(Int(burned)))
                }
                HStack {
                    Button(running ? "Pause" : "Start") { running ? pause() : start() }
                        .buttonStyle(GoldButtonStyle())
                    Button("Finish") { finish() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(20)
        }
        .navigationTitle("IWT Walk")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var paceString: String {
        guard gps.distanceMeters > 20, elapsed > 0 else { return "—" }
        let secPerKm = Double(elapsed) / (gps.distanceMeters / 1000)
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", m, s)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        MogCard {
            VStack {
                Text(label).font(.caption).foregroundStyle(MogTheme.muted)
                Text(value).font(.headline)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func start() {
        if !gps.isTracking { gps.start() }
        running = true
        remaining = currentBlock.seconds
        startTimer()
    }

    private func pause() {
        running = false
        stopTimerOnly()
    }

    private func startTimer() {
        stopTimerOnly()
        let t = Timer(timeInterval: 1, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimerOnly() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard running else { return }
        remaining -= 1
        elapsed += 1
        burned += WorkoutPresets.calories(mets: currentBlock.mets, kg: bodyKg, seconds: 1)
        if remaining <= 0 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if index + 1 < blocks.count {
                index += 1
                remaining = currentBlock.seconds
            } else {
                finish()
            }
        }
    }

    private func finish() {
        running = false
        stopTimerOnly()
        gps.stop()
        history.add(SavedWorkout(
            id: UUID(),
            kind: .japaneseWalking,
            startedAt: Date().addingTimeInterval(-Double(elapsed)),
            elapsedSec: elapsed,
            distanceMeters: gps.distanceMeters,
            calories: burned,
            route: gps.route
        ))
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
