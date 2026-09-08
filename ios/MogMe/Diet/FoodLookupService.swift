import Foundation
import Vision
import UIKit

/// Name + label lookup against Open Food Facts and a bundled catalog.
/// No generative AI — OCR is on-device Vision, calories come from public nutrition DBs.
actor FoodLookupService {
    private let session: URLSession
    private let localFoods: [FoodHit]

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 18
        session = URLSession(configuration: config)
        localFoods = Self.loadBundledFoods()
    }

    func search(query: String) async throws -> [FoodHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { throw FoodLookupError.emptyQuery }

        let local = localFoods.filter { $0.name.localizedCaseInsensitiveContains(q) }
        do {
            async let off = openFoodFacts(q)
            let remote = try await off
            return merge(local + remote)
        } catch {
            if !local.isEmpty { return local }
            throw FoodLookupError.network
        }
    }

    /// Reads packaging / nutrition-label text, then searches by the extracted name.
    func searchFromLabelImage(_ image: UIImage) async throws -> [FoodHit] {
        let text = await recognizeText(image)
        let query = Self.bestQuery(from: text)
        if query.count >= 2 {
            return try await search(query: query)
        }
        return []
    }

    private func openFoodFacts(_ query: String) async throws -> [FoodHit] {
        var comps = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        comps.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
        ]
        guard let url = comps.url else { return [] }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FoodLookupError.network
        }
        let decoded = try JSONDecoder().decode(OFFSearch.self, from: data)
        return (decoded.products ?? []).compactMap { product in
            guard let name = product.productName, !name.isEmpty else { return nil }
            let kcal = product.nutriments?.energyKcal100g ?? product.nutriments?.energyKcalServing
            guard let calories = kcal, calories > 0, calories < 1200 else { return nil }
            return FoodHit(
                id: product.code ?? name,
                name: name,
                brand: product.brands,
                calories: calories,
                protein: product.nutriments?.proteins100g,
                carbs: product.nutriments?.carbohydrates100g,
                fat: product.nutriments?.fat100g,
                serving: product.servingSize ?? "100 g",
                source: "Open Food Facts",
                imageURL: product.imageURL.flatMap(URL.init(string:))
            )
        }
    }

    private func merge(_ items: [FoodHit]) -> [FoodHit] {
        var seen = Set<String>()
        var out: [FoodHit] = []
        for item in items {
            let key = item.name.lowercased()
            if seen.insert(key).inserted { out.append(item) }
            if out.count >= 30 { break }
        }
        return out
    }

    private func recognizeText(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    static func bestQuery(from ocr: String) -> String {
        let lines = ocr
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
        let skip = ["nutrition", "facts", "calories", "ingredients", "serving", "total", "daily"]
        for line in lines {
            let lower = line.lowercased()
            if skip.contains(where: { lower.contains($0) }) { continue }
            if line.rangeOfCharacter(from: .decimalDigits) != nil && line.count < 8 { continue }
            return String(line.prefix(48))
        }
        return String((lines.first ?? "").prefix(48))
    }

    private static func loadBundledFoods() -> [FoodHit] {
        guard
            let url = Bundle.main.url(forResource: "foods", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let rows = try? JSONDecoder().decode([BundledFood].self, from: data)
        else { return Self.fallbackFoods }
        return rows.map {
            FoodHit(
                id: $0.id,
                name: $0.name,
                brand: nil,
                calories: $0.calories,
                protein: $0.protein,
                carbs: $0.carbs,
                fat: $0.fat,
                serving: $0.serving,
                source: "MogMe catalog",
                imageURL: nil
            )
        }
    }

    private static let fallbackFoods: [FoodHit] = [
        FoodHit(id: "apple", name: "Apple", brand: nil, calories: 95, protein: 0.5, carbs: 25, fat: 0.3, serving: "1 medium", source: "MogMe catalog", imageURL: nil),
        FoodHit(id: "banana", name: "Banana", brand: nil, calories: 105, protein: 1.3, carbs: 27, fat: 0.4, serving: "1 medium", source: "MogMe catalog", imageURL: nil),
        FoodHit(id: "egg", name: "Egg, large", brand: nil, calories: 72, protein: 6.3, carbs: 0.4, fat: 4.8, serving: "1 large", source: "MogMe catalog", imageURL: nil),
        FoodHit(id: "chicken", name: "Chicken breast, cooked", brand: nil, calories: 165, protein: 31, carbs: 0, fat: 3.6, serving: "100 g", source: "MogMe catalog", imageURL: nil),
        FoodHit(id: "rice", name: "White rice, cooked", brand: nil, calories: 206, protein: 4.3, carbs: 45, fat: 0.4, serving: "1 cup", source: "MogMe catalog", imageURL: nil),
    ]
}

private struct BundledFood: Decodable {
    let id: String
    let name: String
    let calories: Double
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let serving: String
}

private struct OFFSearch: Decodable {
    let products: [OFFProduct]?
}

private struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let brands: String?
    let servingSize: String?
    let imageURL: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case imageURL = "image_front_small_url"
        case nutriments
    }
}

private struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let energyKcalServing: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
}
