import SwiftUI

struct IntervalCardioView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var workSec = 60
    @State private var restSec = 60
    @State private var rounds = 8

    private var session: WorkoutRuntime { appState.cardioRuntime }
    private var gps: WorkoutLocationEngine { appState.cardioGPS }

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 14) {
                if scenePhase == .active {
                    WorkoutMapView(route: gps.route, isHard: session.currentBlock?.isHard ?? true)
                        .frame(height: 200)
                } else {
                    MogCard {
                        Text("Intervals, GPS, and calories keep running in the background until this session completes.")
                            .font(.footnote)
                            .foregroundStyle(MogTheme.muted)
                    }
                }
                MogCard {
                    VStack(spacing: 8) {
                        Text(session.currentBlock?.label ?? "Set your intervals").font(.title3.bold())
                        Text(clock(session.remaining == 0 && !session.isRunning ? workSec : session.remaining))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text(gps.statusMessage).font(.caption).foregroundStyle(MogTheme.muted)
                        if session.isRunning {
                            Text("Background tracking on · leave the app if you want")
                                .font(.caption2)
                                .foregroundStyle(MogTheme.gold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                if !session.isRunning && session.blocks.isEmpty {
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
                    stat("kcal", String(Int(session.burned)))
                }
                HStack {
                    Button(session.isRunning ? "Pause" : "Start") {
                        if session.isRunning {
                            session.pause()
                        } else {
                            if session.blocks.isEmpty {
                                session.prepareCardio(workSec: workSec, restSec: restSec, rounds: rounds)
                            }
                            session.start()
                        }
                    }
                    .buttonStyle(GoldButtonStyle())
                    Button("Finish") { session.finish() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(20)
        }
        .navigationTitle("Interval Cardio")
        .navigationBarTitleDisplayMode(.inline)
        .crownToolbar()
        .onAppear {
            if appState.pendingCardioStart {
                appState.pendingCardioStart = false
                if session.blocks.isEmpty {
                    session.prepareCardio(workSec: workSec, restSec: restSec, rounds: rounds)
                }
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

    private func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }
}
