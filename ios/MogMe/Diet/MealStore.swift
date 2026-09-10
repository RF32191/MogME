import Foundation
import UIKit

@MainActor
final class MealStore: ObservableObject {
    @Published private(set) var meals: [LoggedMeal] = []

    private let fileURL: URL
    private let imagesDir: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("meals.json")
        imagesDir = docs.appendingPathComponent("MealPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
    }

    var todayCalories: Double {
        let cal = Calendar.current
        return meals.filter { cal.isDateInToday($0.createdAt) }.reduce(0) { $0 + $1.calories }
    }

    func image(for meal: LoggedMeal) -> UIImage? {
        guard let name = meal.localImageName else { return nil }
        let url = imagesDir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func log(hit: FoodHit, image: UIImage?, note: String? = nil) {
        var filename: String?
        if let image, let data = ImageCompressor.jpegForMeal(image) {
            filename = "\(UUID().uuidString).jpg"
            try? data.write(to: imagesDir.appendingPathComponent(filename!), options: .atomic)
        }
        let meal = LoggedMeal(
            id: UUID(),
            name: hit.name,
            calories: hit.calories,
            protein: hit.protein,
            carbs: hit.carbs,
            fat: hit.fat,
            fiber: hit.fiber,
            sugars: hit.sugars,
            sodium: hit.sodium,
            serving: hit.serving,
            source: hit.source,
            localImageName: filename,
            note: note,
            createdAt: Date()
        )
        meals.insert(meal, at: 0)
        persist()
    }

    func delete(_ meal: LoggedMeal) {
        if let name = meal.localImageName {
            try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(name))
        }
        meals.removeAll { $0.id == meal.id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        meals = (try? JSONDecoder().decode([LoggedMeal].self, from: data)) ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(Array(meals.prefix(400))) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
