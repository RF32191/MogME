import Foundation

struct FoodHit: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var brand: String?
    var calories: Double
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var serving: String
    var source: String
    var imageURL: URL?
}

struct LoggedMeal: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var calories: Double
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var serving: String
    var source: String
    var localImageName: String?
    var createdAt: Date
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
