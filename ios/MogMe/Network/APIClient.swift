import Foundation
import UIKit

struct APIClient {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        try await request(path, method: "GET", body: nil as Data?, as: type)
    }

    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body, as type: T.Type = T.self) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(path, method: "POST", body: data, as: type)
    }

    private func request<T: Decodable>(_ path: String, method: String, body: Data?, as type: T.Type) async throws -> T {
        var url = baseURL
        url.append(path: path.hasPrefix("/") ? String(path.dropFirst()) : path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw APIError.http(http.statusCode, message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum APIError: LocalizedError {
    case badResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .badResponse: return "The server did not respond."
        case .http(let code, let body): return "Server \(code): \(body)"
        }
    }
}

@MainActor
enum ImageCompressor {
    /// Chat screenshots stay readable but under Railway's vision budget (~180KB JPEG).
    static func jpegForWingman(_ image: UIImage) -> Data? {
        var maxEdge: CGFloat = 1024
        var quality: CGFloat = 0.62
        for _ in 0..<6 {
            let size = image.size
            guard size.width > 0, size.height > 0 else { return nil }
            let longest = max(size.width, size.height)
            let scale = longest > maxEdge ? maxEdge / longest : 1
            let target = CGSize(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
            let renderer = UIGraphicsImageRenderer(size: target)
            let rendered = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
            if let data = rendered.jpegData(compressionQuality: quality), data.count <= 180_000 {
                return data
            }
            maxEdge *= 0.82
            quality = max(0.32, quality - 0.08)
        }
        return image.jpegData(compressionQuality: 0.32)
    }

    static func jpegForIdentify(_ image: UIImage) -> Data? {
        jpegForWingman(image)
    }

    static func jpegForMeal(_ image: UIImage) -> Data? {
        let maxEdge: CGFloat = 1600
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: target)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.72)
    }
}
