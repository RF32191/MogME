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

    private var apiBase: URL?

    func use(apiBase: URL) {
        self.apiBase = apiBase
    }

    func search(query: String) async throws -> [FoodHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { throw FoodLookupError.emptyQuery }

        let local = localFoods.filter { $0.name.localizedCaseInsensitiveContains(q) }
        var remote: [FoodHit] = []
        if let apiBase {
            remote.append(contentsOf: (try? await railwaySearch(q, base: apiBase)) ?? [])
        }
        remote.append(contentsOf: (try? await openFoodFacts(q)) ?? [])
        remote.append(contentsOf: (try? await usdaSearch(q)) ?? [])
        let merged = merge(local + remote)
        if merged.isEmpty { throw FoodLookupError.network }
        return merged
    }

    /// Reads packaging / nutrition-label text, then searches by the extracted name.
    func searchFromLabelImage(_ image: UIImage) async throws -> [FoodHit] {
        let read = await readMealPhoto(image)
        let query = read.suggestedName.isEmpty ? read.description : read.suggestedName
        if query.count >= 2 {
            return try await search(query: query)
        }
        return []
    }

    func searchFromDescription(_ text: String) async throws -> [FoodHit] {
        try await search(query: Self.searchTerms(from: text))
    }

    /// On-device description: Vision classification + OCR. Calories still come from the name search.
    func readMealPhoto(_ image: UIImage) async -> MealPhotoRead {
        async let ocr = recognizeText(image)
        async let labels = classifyFood(image)
        let text = await ocr
        let tags = await labels
        return Self.composeDescription(ocr: text, labels: tags)
    }

    static func composeDescription(ocr: String, labels: [String]) -> MealPhotoRead {
        let product = bestQuery(from: ocr)
        let foodLabels = labels.filter { !["food", "meal", "dish", "plate", "cuisine"].contains($0.lowercased()) }
        let labelPhrase = foodLabels.prefix(3).joined(separator: ", ")
        let suggested = product.count >= 2 ? product : (foodLabels.first ?? "")
        var parts: [String] = []
        if !suggested.isEmpty { parts.append(suggested) }
        if !labelPhrase.isEmpty, !labelPhrase.localizedCaseInsensitiveContains(suggested) {
            parts.append("Looks like \(labelPhrase).")
        }
        if product.count >= 2, !foodLabels.isEmpty {
            parts.append("Label text was readable on the package.")
        } else if product.isEmpty, foodLabels.isEmpty {
            parts.append("Could not read a clear food name. Type what this is.")
        }
        return MealPhotoRead(
            suggestedName: suggested,
            description: parts.joined(separator: " "),
            ocr: ocr
        )
    }

    static func searchTerms(from text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "Looks like ", with: "")
            .replacingOccurrences(of: "Label text was readable on the package.", with: "")
            .replacingOccurrences(of: "Could not read a clear food name. Type what this is.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = cleaned.split(whereSeparator: \.isNewline).first.map(String.init) ?? cleaned
        return String(firstLine.prefix(64))
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
            let kcal = product.nutriments?.energyKcal100g
                ?? product.nutriments?.energyKcalServing
                ?? product.nutriments?.energyKj100g.map { $0 / 4.184 }
            guard let calories = kcal, calories > 0, calories < 2500 else { return nil }
            return FoodHit(
                id: product.code ?? name,
                name: name,
                brand: product.brands,
                calories: calories,
                protein: product.nutriments?.proteins100g,
                carbs: product.nutriments?.carbohydrates100g,
                fat: product.nutriments?.fat100g,
                fiber: product.nutriments?.fiber100g,
                sugars: product.nutriments?.sugars100g,
                sodium: product.nutriments?.sodium100g.map { $0 * 1000 },
                serving: product.servingSize ?? "100 g",
                source: "Open Food Facts",
                imageURL: product.imageURL.flatMap(URL.init(string:)),
                analysis: "\(name) — \(Int(calories)) kcal per \(product.servingSize ?? "100 g") from Open Food Facts."
            )
        }
    }

    private func railwaySearch(_ query: String, base: URL) async throws -> [FoodHit] {
        var url = base
        url.append(path: "food/search")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let final = comps.url else { return [] }
        let (data, response) = try await session.data(from: final)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        let decoded = try JSONDecoder().decode(RailwayFoods.self, from: data)
        return (decoded.foods ?? []).map {
            FoodHit(
                id: $0.id,
                name: $0.name,
                brand: $0.brand,
                calories: $0.calories,
                protein: $0.protein,
                carbs: $0.carbs,
                fat: $0.fat,
                fiber: $0.fiber,
                sugars: $0.sugars,
                sodium: $0.sodium,
                serving: $0.serving,
                source: $0.source,
                imageURL: nil,
                analysis: $0.analysis
            )
        }
    }

    private func usdaSearch(_ query: String) async throws -> [FoodHit] {
        var comps = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        comps.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "10"),
            URLQueryItem(name: "api_key", value: "DEMO_KEY"),
        ]
        guard let url = comps.url else { return [] }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return [] }
        let decoded = try JSONDecoder().decode(USDASearch.self, from: data)
        return (decoded.foods ?? []).compactMap { food in
            guard let name = food.description, !name.isEmpty else { return nil }
            func pick(_ keys: [String]) -> Double? {
                food.foodNutrients?.first { n in
                    keys.contains { (n.nutrientName ?? "").localizedCaseInsensitiveContains($0) }
                }?.value
            }
            guard let calories = pick(["Energy", "calorie"]), calories > 0, calories < 2500 else { return nil }
            let serving = food.servingSize.map { "\($0) \(food.servingSizeUnit ?? "g")" } ?? "100 g"
            return FoodHit(
                id: String(food.fdcId ?? 0),
                name: name,
                brand: food.brandName,
                calories: calories,
                protein: pick(["Protein"]),
                carbs: pick(["Carbohydrate"]),
                fat: pick(["Total lipid", "Fat"]),
                fiber: pick(["Fiber"]),
                sugars: pick(["Sugar"]),
                sodium: pick(["Sodium"]),
                serving: serving,
                source: "USDA FoodData Central",
                imageURL: nil,
                analysis: "\(name) — \(Int(calories)) kcal per \(serving) from USDA."
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
        guard let cg = image.orientedCGImage else { return "" }
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

    private func classifyFood(_ image: UIImage) async -> [String] {
        guard let cg = image.orientedCGImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let names = observations
                    .filter { $0.confidence >= 0.15 }
                    .prefix(8)
                    .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
                continuation.resume(returning: Array(names))
            }
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
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
                imageURL: nil,
                analysis: "\($0.name) — \(Int($0.calories)) kcal per \($0.serving) from the MogMe catalog."
            )
        }
    }

    private static let fallbackFoods: [FoodHit] = [
        FoodHit(id: "apple", name: "Apple", brand: nil, calories: 95, protein: 0.5, carbs: 25, fat: 0.3, serving: "1 medium", source: "MogMe catalog", imageURL: nil, analysis: "Apple — 95 kcal per 1 medium from the MogMe catalog."),
        FoodHit(id: "banana", name: "Banana", brand: nil, calories: 105, protein: 1.3, carbs: 27, fat: 0.4, serving: "1 medium", source: "MogMe catalog", imageURL: nil, analysis: "Banana — 105 kcal per 1 medium from the MogMe catalog."),
        FoodHit(id: "egg", name: "Egg, large", brand: nil, calories: 72, protein: 6.3, carbs: 0.4, fat: 4.8, serving: "1 large", source: "MogMe catalog", imageURL: nil, analysis: "Egg — 72 kcal per 1 large from the MogMe catalog."),
        FoodHit(id: "chicken", name: "Chicken breast, cooked", brand: nil, calories: 165, protein: 31, carbs: 0, fat: 3.6, serving: "100 g", source: "MogMe catalog", imageURL: nil, analysis: "Chicken breast — 165 kcal per 100 g from the MogMe catalog."),
        FoodHit(id: "rice", name: "White rice, cooked", brand: nil, calories: 206, protein: 4.3, carbs: 45, fat: 0.4, serving: "1 cup", source: "MogMe catalog", imageURL: nil, analysis: "White rice — 206 kcal per 1 cup from the MogMe catalog."),
    ]
}

private extension UIImage {
    /// Camera frames are often `.right`; Vision needs a drawn, upright bitmap.
    var orientedCGImage: CGImage? {
        if imageOrientation == .up, let cgImage { return cgImage }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
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
    let energyKj100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let sodium100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKcalServing = "energy-kcal_serving"
        case energyKj100g = "energy_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
    }
}

private struct RailwayFoods: Decodable {
    let foods: [RailwayFood]?
}

private struct RailwayFood: Decodable {
    let id: String
    let name: String
    let brand: String?
    let calories: Double
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sugars: Double?
    let sodium: Double?
    let serving: String
    let source: String
    let analysis: String?
}

private struct USDASearch: Decodable {
    let foods: [USDAFood]?
}

private struct USDAFood: Decodable {
    let fdcId: Int?
    let description: String?
    let brandName: String?
    let servingSize: Double?
    let servingSizeUnit: String?
    let foodNutrients: [USDANutrient]?
}

private struct USDANutrient: Decodable {
    let nutrientName: String?
    let value: Double?
}
