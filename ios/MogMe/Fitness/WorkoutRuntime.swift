import Foundation
import Combine
import UIKit

/// Owns interval timing off the workout screen. Lives on AppState so leaving
/// Train, locking the phone, or multitasking cannot kill the session.
final class WorkoutRuntime: ObservableObject {
    let kind: WorkoutKind
    let gps: WorkoutLocationEngine

    @Published private(set) var isRunning = false
    @Published private(set) var blocks: [IntervalBlock] = []
    @Published private(set) var index = 0
    @Published private(set) var remaining = 0
    @Published private(set) var elapsed = 0
    @Published private(set) var burned = 0.0
    @Published var bodyKg = 75.0

    var persist: ((SavedWorkout) -> Void)?

    private var runStarted: Date?
    private var pausedElapsed = 0
    private var timer: Timer?
    private let tickQueue = DispatchQueue(label: "com.mogme.workout.\(UUID().uuidString.prefix(6))", qos: .userInitiated)

    init(kind: WorkoutKind, gps: WorkoutLocationEngine) {
        self.kind = kind
        self.gps = gps
        gps.onFix = { [weak self] in
            self?.tick()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.tick()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.tick()
        }
    }

    var currentBlock: IntervalBlock? {
        guard !blocks.isEmpty else { return nil }
        return blocks[min(index, blocks.count - 1)]
    }

    func prepareJapaneseWalking() {
        guard !isRunning else { return }
        blocks = WorkoutPresets.japaneseWalking()
        index = 0
        remaining = blocks[0].seconds
        elapsed = 0
        burned = 0
        pausedElapsed = 0
        runStarted = nil
    }

    func prepareCardio(workSec: Int, restSec: Int, rounds: Int) {
        guard !isRunning else { return }
        blocks = WorkoutPresets.intervalCardio(workSec: workSec, restSec: restSec, rounds: rounds)
        index = 0
        remaining = blocks[0].seconds
        elapsed = 0
        burned = 0
        pausedElapsed = 0
        runStarted = nil
    }

    func start() {
        if blocks.isEmpty {
            if kind == .japaneseWalking {
                prepareJapaneseWalking()
            } else {
                prepareCardio(workSec: 60, restSec: 60, rounds: 8)
            }
        }
        if !gps.isTracking { gps.start() }
        isRunning = true
        runStarted = Date().addingTimeInterval(TimeInterval(-pausedElapsed))
        startTimer()
        tick()
    }

    func pause() {
        guard isRunning else { return }
        tick()
        isRunning = false
        pausedElapsed = elapsed
        stopTimer()
    }

    func finish() {
        let hadSession = isRunning || !blocks.isEmpty
        let snap = WorkoutTimeline.snapshot(elapsed: max(elapsed, 0), blocks: blocks, kg: bodyKg)
        isRunning = false
        stopTimer()
        gps.stop()
        guard hadSession else { return }
        remaining = 0
        burned = snap.burned
        let workout = SavedWorkout(
            id: UUID(),
            kind: kind,
            startedAt: Date().addingTimeInterval(-Double(max(1, snap.elapsed))),
            elapsedSec: snap.elapsed,
            distanceMeters: gps.snapshotDistance(),
            calories: snap.burned,
            route: gps.snapshotRoute()
        )
        persist?(workout)
        blocks = []
        index = 0
        elapsed = 0
        pausedElapsed = 0
        runStarted = nil
    }

    func tick() {
        guard isRunning else { return }
        let started = runStarted ?? Date()
        let kg = bodyKg
        let currentBlocks = blocks
        tickQueue.async { [weak self] in
            let elapsed = max(0, Int(Date().timeIntervalSince(started)))
            let snap = WorkoutTimeline.snapshot(elapsed: elapsed, blocks: currentBlocks, kg: kg)
            DispatchQueue.main.async {
                guard let self, self.isRunning else { return }
                self.elapsed = snap.elapsed
                self.index = snap.index
                self.remaining = snap.remaining
                self.burned = snap.burned
                if snap.finished {
                    self.finish()
                }
            }
        }
    }

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
