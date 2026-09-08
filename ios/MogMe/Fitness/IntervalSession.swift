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
