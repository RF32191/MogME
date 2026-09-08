import SwiftUI

struct IntervalCardioView: View {
    @ObservedObject var history: WorkoutHistoryStore
    @EnvironmentObject private var appState: AppState
    @StateObject private var gps = WorkoutLocationEngine()
    @State private var workSec = 60
    @State private var restSec = 60
    @State private var rounds = 8
    @State private var blocks: [IntervalBlock] = []
    @State private var index = 0
    @State private var remaining = 60
    @State private var running = false
    @State private var elapsed = 0
    @State private var burned = 0.0
    @State private var bodyKg = 75.0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 14) {
                WorkoutMapView(route: gps.route, isHard: current?.isHard ?? true)
                    .frame(height: 200)
                MogCard {
                    VStack(spacing: 8) {
                        Text(current?.label ?? "Set your intervals").font(.title3.bold())
                        Text(clock(remaining)).font(.system(size: 48, weight: .bold, design: .rounded))
                        Text(gps.statusMessage).font(.caption).foregroundStyle(MogTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
                if !running && blocks.isEmpty {
                    MogCard {
                        VStack(alignment: .leading, spacing: 10) {
                            stepper("Work", $workSec, 15...300)
                            stepper("Recover", $restSec, 10...240)
                            stepper("Rounds", $rounds, 2...20)
                        }
                    }
                }
                HStack {
                    stat("Distance", String(format: "%.2f km", gps.distanceMeters / 1000))
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
        .navigationTitle("Interval Cardio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if appState.pendingCardioStart {
                appState.pendingCardioStart = false
                start()
            }
        }
        .onDisappear { stopTimerOnly() }
    }

    private var current: IntervalBlock? {
        guard !blocks.isEmpty else { return nil }
        return blocks[min(index, blocks.count - 1)]
    }

    private func stepper(_ title: String, _ value: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        Stepper("\(title): \(value.wrappedValue)s", value: value, in: range, step: 5)
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
        if blocks.isEmpty {
            blocks = WorkoutPresets.intervalCardio(workSec: workSec, restSec: restSec, rounds: rounds)
            index = 0
            remaining = blocks[0].seconds
        }
        if !gps.isTracking { gps.start() }
        running = true
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
        guard running, let block = current else { return }
        remaining -= 1
        elapsed += 1
        burned += WorkoutPresets.calories(mets: block.mets, kg: bodyKg, seconds: 1)
        if remaining <= 0 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if index + 1 < blocks.count {
                index += 1
                remaining = blocks[index].seconds
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
            kind: .intervalCardio,
            startedAt: Date().addingTimeInterval(-Double(elapsed)),
            elapsedSec: elapsed,
            distanceMeters: gps.distanceMeters,
            calories: burned,
            route: gps.route
        ))
        blocks = []
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
