import Foundation
import UIKit

struct WingmanUsage: Codable, Hashable {
    var requestsToday: Int
    var requestsRemaining: Int
    var tokensToday: Int
    var tokensRemaining: Int
    var estimatedCostUsdToday: Double
    var thisRequest: WingmanRequestCost?
}

struct WingmanRequestCost: Codable, Hashable {
    var inputTokens: Int
    var outputTokens: Int
    var estimatedCostUsd: Double
}

struct WingmanAdvice: Codable, Hashable {
    var ok: Bool
    var reason: String?
    var advice: String?
    var suggestedReplies: [String]?
    var usage: WingmanUsage?
}

struct WingmanChatTurn: Codable, Hashable {
    var role: String
    var content: String
}

@MainActor
final class WingmanService: ObservableObject {
    @Published var advice = ""
    @Published var replies: [String] = []
    @Published var usageText = "40 cheap gpt-4o-mini turns / day"
    @Published var busy = false
    @Published var error: String?
    @Published var history: [WingmanChatTurn] = []

    func advise(baseURL: URL, userKey: String, goal: String, text: String, image: UIImage?, memory: PartnerProfile?) async {
        busy = true
        error = nil
        defer { busy = false }
        var body: [String: Any] = [
            "userKey": userKey,
            "goal": goal,
            "text": text,
            "history": history.suffix(6).map { ["role": $0.role, "content": $0.content] },
        ]
        if let memory {
            body["memory"] = [
                "name": memory.name,
                "notes": memory.notes,
                "style": memory.style,
                "facts": Array(memory.facts.prefix(8)),
                "doNots": Array(memory.doNots.prefix(6)),
                "lastTopics": Array(memory.lastTopics.prefix(6)),
            ]
        }
        if let image, let data = ImageCompressor.jpegForWingman(image) {
            body["imageDataUrl"] = "data:image/jpeg;base64,\(data.base64EncodedString())"
        }
        do {
            var url = baseURL
            url.append(path: "wingman/advise")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(WingmanAdvice.self, from: data)
            if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                error = "Daily wingman budget reached. \(decoded.reason ?? "")"
                return
            }
            guard decoded.ok else {
                error = decoded.reason ?? "Wingman declined that request."
                return
            }
            advice = decoded.advice ?? ""
            replies = decoded.suggestedReplies ?? []
            if let usage = decoded.usage {
                usageText = String(
                    format: "%d left today · $%.4f so far · this turn $%.4f",
                    usage.requestsRemaining,
                    usage.estimatedCostUsdToday,
                    usage.thisRequest?.estimatedCostUsd ?? 0
                )
            }
            if !text.isEmpty {
                history.append(WingmanChatTurn(role: "user", content: String(text.prefix(280))))
            }
            if !advice.isEmpty {
                history.append(WingmanChatTurn(role: "assistant", content: String(advice.prefix(280))))
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
