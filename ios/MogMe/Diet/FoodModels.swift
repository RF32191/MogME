import Foundation

struct FoodHit: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var brand: String?
    var calories: Double
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?
    var sugars: Double?
    var sodium: Double?
    var serving: String
    var source: String
    var imageURL: URL?
    var analysis: String?

    var headline: String {
        analysis ?? "\(name) — \(Int(calories)) kcal per \(serving) (\(source))."
    }
}

struct LoggedMeal: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var calories: Double
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?
    var sugars: Double?
    var sodium: Double?
    var serving: String
    var source: String
    var localImageName: String?
    var note: String?
    var createdAt: Date

    var asHit: FoodHit {
        FoodHit(
            id: id.uuidString,
            name: name,
            brand: nil,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sugars: sugars,
            sodium: sodium,
            serving: serving,
            source: source,
            imageURL: nil,
            analysis: nil
        )
    }
}

struct MealPhotoRead: Sendable, Hashable {
    var suggestedName: String
    var description: String
    var ocr: String
}

enum FoodLookupError: LocalizedError {
    case emptyQuery
    case network

    var errorDescription: String? {
        switch self {
        case .emptyQuery: return "Type a food name to search calories."
        case .network: return "Could not reach the food databases."
        }
    }
}
