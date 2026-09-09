import Foundation

enum WorkoutKind: String, Codable, CaseIterable, Identifiable {
    case japaneseWalking
    case intervalCardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .japaneseWalking: return "Japanese Walking"
        case .intervalCardio: return "Interval Cardio"
        }
    }
}

struct IntervalBlock: Hashable, Sendable {
    let label: String
    let seconds: Int
    let isHard: Bool
    let mets: Double
}

enum WorkoutPresets {
    /// Interval Walking Training: 3 min brisk / 3 min easy, typically 5 cycles (30 min).
    static func japaneseWalking(cycles: Int = 5) -> [IntervalBlock] {
        (0..<max(1, cycles)).flatMap { i in
            [
                IntervalBlock(label: "Brisk \(i + 1)", seconds: 180, isHard: true, mets: 4.8),
                IntervalBlock(label: "Easy \(i + 1)", seconds: 180, isHard: false, mets: 2.8),
            ]
        }
    }

    static func intervalCardio(workSec: Int, restSec: Int, rounds: Int) -> [IntervalBlock] {
        (0..<max(1, rounds)).flatMap { i in
            [
                IntervalBlock(label: "Work \(i + 1)", seconds: max(15, workSec), isHard: true, mets: 9.0),
                IntervalBlock(label: "Recover \(i + 1)", seconds: max(10, restSec), isHard: false, mets: 3.5),
            ]
        }
    }

    static func calories(mets: Double, kg: Double, seconds: Int) -> Double {
        mets * kg * (Double(seconds) / 3600.0)
    }
}

/// Wall-clock catch-up so a backgrounded walk/cardio can skip finished
/// intervals and complete without the UI staying open.
enum WorkoutTimeline {
    struct Snapshot: Equatable, Sendable {
        var index: Int
        var remaining: Int
        var elapsed: Int
        var burned: Double
        var finished: Bool
    }

    static func snapshot(elapsed: Int, blocks: [IntervalBlock], kg: Double) -> Snapshot {
        guard !blocks.isEmpty else {
            return Snapshot(index: 0, remaining: 0, elapsed: max(0, elapsed), burned: 0, finished: true)
        }
        let t = max(0, elapsed)
        let total = blocks.reduce(0) { $0 + $1.seconds }
        if t >= total {
            let kcal = blocks.reduce(0.0) { $0 + WorkoutPresets.calories(mets: $1.mets, kg: kg, seconds: $1.seconds) }
            return Snapshot(index: max(0, blocks.count - 1), remaining: 0, elapsed: t, burned: kcal, finished: true)
        }
        var consumed = 0
        var kcal = 0.0
        for (i, block) in blocks.enumerated() {
            if t < consumed + block.seconds {
                let used = t - consumed
                kcal += WorkoutPresets.calories(mets: block.mets, kg: kg, seconds: used)
                return Snapshot(index: i, remaining: block.seconds - used, elapsed: t, burned: kcal, finished: false)
            }
            kcal += WorkoutPresets.calories(mets: block.mets, kg: kg, seconds: block.seconds)
            consumed += block.seconds
        }
        return Snapshot(index: blocks.count - 1, remaining: 0, elapsed: t, burned: kcal, finished: true)
    }
}

struct SavedWorkout: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: WorkoutKind
    var startedAt: Date
    var elapsedSec: Int
    var distanceMeters: Double
    var calories: Double
    var route: [GPSPoint]
}

@MainActor
final class WorkoutHistoryStore: ObservableObject {
    @Published private(set) var items: [SavedWorkout] = []
    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = dir.appendingPathComponent("workouts.json")
        load()
    }

    func add(_ workout: SavedWorkout) {
        items.insert(workout, at: 0)
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        items = (try? JSONDecoder().decode([SavedWorkout].self, from: data)) ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(Array(items.prefix(80))) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
