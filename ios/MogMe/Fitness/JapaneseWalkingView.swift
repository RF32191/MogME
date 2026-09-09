import SwiftUI

struct JapaneseWalkingView: View {
    @ObservedObject var history: WorkoutHistoryStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var blocks = WorkoutPresets.japaneseWalking()
    @State private var index = 0
    @State private var remaining = 180
    @State private var running = false
    @State private var elapsed = 0
    @State private var burned = 0.0
    @State private var bodyKg = 75.0
    @State private var segmentEnd: Date?
    @State private var runStarted: Date?
    @State private var pausedElapsed = 0
    @State private var timer: Timer?

    private var gps: WorkoutLocationEngine { appState.walkGPS }

    var body: some View {
        workoutChrome
            .navigationTitle("IWT Walk")
            .navigationBarTitleDisplayMode(.inline)
            .crownToolbar()
            .onAppear {
                if appState.pendingWalkStart {
                    appState.pendingWalkStart = false
                    start()
                } else if running {
                    startTimer()
                }
            }
            .onReceive(gps.objectWillChange) { _ in }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, running { syncFromWallClock() }
            }
    }

    private var currentBlock: IntervalBlock {
        blocks[min(index, max(blocks.count - 1, 0))]
    }

    private var workoutChrome: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 14) {
                if scenePhase == .active {
                    WorkoutMapView(route: gps.route, isHard: currentBlock.isHard)
                        .frame(height: 220)
                } else {
                    MogCard { Text("GPS keeps recording in the background.").font(.footnote).foregroundStyle(MogTheme.muted) }
                }
                MogCard {
                    VStack(spacing: 8) {
                        Text("Japanese Walking").font(.headline)
                        Text(currentBlock.label).font(.title2.bold()).foregroundStyle(currentBlock.isHard ? Color.orange : MogTheme.gold)
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
    }

    private var paceString: String {
        guard gps.distanceMeters > 20, elapsed > 0 else { return "—" }
        let secPerKm = Double(elapsed) / (gps.distanceMeters / 1000)
        return String(format: "%d:%02d /km", Int(secPerKm) / 60, Int(secPerKm) % 60)
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
        segmentEnd = Date().addingTimeInterval(TimeInterval(remaining))
        runStarted = Date().addingTimeInterval(TimeInterval(-pausedElapsed))
        startTimer()
    }

    private func pause() {
        running = false
        pausedElapsed = elapsed
        stopTimerOnly()
    }

    private func startTimer() {
        stopTimerOnly()
        let t = Timer(timeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async { syncFromWallClock() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimerOnly() {
        timer?.invalidate()
        timer = nil
    }

    private func syncFromWallClock() {
        guard running else { return }
        if let start = runStarted {
            elapsed = max(0, Int(Date().timeIntervalSince(start)))
        }
        if let end = segmentEnd {
            remaining = max(0, Int(end.timeIntervalSinceNow.rounded()))
        }
        burned = WorkoutPresets.calories(mets: currentBlock.mets, kg: bodyKg, seconds: max(1, currentBlock.seconds - remaining))
            + WorkoutPresets.calories(mets: 3.5, kg: bodyKg, seconds: max(0, elapsed - (currentBlock.seconds - remaining)))
        if remaining <= 0 {
            if index + 1 < blocks.count {
                index += 1
                remaining = currentBlock.seconds
                segmentEnd = Date().addingTimeInterval(TimeInterval(remaining))
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
            distanceMeters: gps.snapshotDistance(),
            calories: burned,
            route: gps.snapshotRoute()
        ))
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
