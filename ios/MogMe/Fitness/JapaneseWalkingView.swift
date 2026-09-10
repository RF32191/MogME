import SwiftUI

struct JapaneseWalkingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    private var session: WorkoutRuntime { appState.walkRuntime }
    private var gps: WorkoutLocationEngine { appState.walkGPS }

    var body: some View {
        workoutChrome
            .navigationTitle("IWT Walk")
            .navigationBarTitleDisplayMode(.inline)
            .crownToolbar()
            .onAppear {
                if session.blocks.isEmpty { session.prepareJapaneseWalking() }
                if appState.pendingWalkStart {
                    appState.pendingWalkStart = false
                    session.start()
                } else {
                    session.tick()
                }
            }
            .onReceive(session.objectWillChange) { _ in }
            .onReceive(gps.objectWillChange) { _ in }
            .onChange(of: scenePhase) { _, _ in
                session.tick()
            }
    }

    private var currentBlock: IntervalBlock {
        session.currentBlock ?? IntervalBlock(label: "Brisk 1", seconds: 180, isHard: true, mets: 4.8)
    }

    private var workoutChrome: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 14) {
                if scenePhase == .active {
                    WorkoutMapView(route: gps.route, isHard: currentBlock.isHard)
                        .frame(height: 220)
                } else {
                    MogCard {
                        Text("GPS and intervals keep running off-screen. This walk will finish itself.")
                            .font(.footnote)
                            .foregroundStyle(MogTheme.muted)
                    }
                }
                MogCard {
                    VStack(spacing: 8) {
                        Text("Japanese Walking").font(.headline)
                        Text(currentBlock.label).font(.title2.bold()).foregroundStyle(currentBlock.isHard ? Color.orange : MogTheme.gold)
                        Text(clock(session.remaining)).font(.system(size: 48, weight: .bold, design: .rounded))
                        Text(gps.statusMessage).font(.caption).foregroundStyle(MogTheme.muted)
                        if session.isRunning {
                            Text("Background tracking on · you can leave this screen")
                                .font(.caption2)
                                .foregroundStyle(MogTheme.gold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                HStack {
                    stat("Distance", String(format: "%.2f km", gps.distanceMeters / 1000))
                    stat("Pace", paceString)
                    stat("kcal", String(Int(session.burned)))
                }
                HStack {
                    Button(session.isRunning ? "Pause" : "Start") { session.isRunning ? session.pause() : session.start() }
                        .buttonStyle(GoldButtonStyle())
                    Button("Finish") { session.finish() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(20)
        }
    }

    private var paceString: String {
        guard gps.distanceMeters > 20, session.elapsed > 0 else { return "—" }
        let secPerKm = Double(session.elapsed) / (gps.distanceMeters / 1000)
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

    private func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
