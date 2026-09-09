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
    var sawImage: Bool?
    var usage: WingmanUsage?
}

struct WingmanChatTurn: Identifiable, Hashable {
    var id = UUID()
    var role: String
    var content: String
    var image: UIImage?
    var usageLine: String?
}

@MainActor
final class WingmanService: ObservableObject {
    @Published var replies: [String] = []
    @Published var usageText = "Image reads spend tokens. ~85 vision tokens + reply."
    @Published var lastUsage: WingmanUsage?
    @Published var busy = false
    @Published var error: String?
    @Published var messages: [WingmanChatTurn] = []

    var historyPayload: [[String: String]] {
        messages.suffix(8).map { ["role": $0.role == "user" ? "user" : "assistant", "content": String($0.content.prefix(280))] }
    }

    func advise(baseURL: URL, userKey: String, goal: String, text: String, image: UIImage?, memory: PartnerProfile?) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || image != nil else {
            error = "Add a chat screenshot or type what they said."
            return
        }
        busy = true
        error = nil
        defer { busy = false }

        let userLine = trimmed.isEmpty ? "Read this chat screenshot and coach the next move." : trimmed
        messages.append(WingmanChatTurn(role: "user", content: userLine, image: image))

        var body: [String: Any] = [
            "userKey": userKey,
            "goal": goal,
            "text": userLine,
            "history": historyPayload.dropLast(),
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
        if let image {
            guard let data = ImageCompressor.jpegForWingman(image) else {
                error = "Could not compress that screenshot. Try cropping to the messages."
                return
            }
            body["imageDataUrl"] = "data:image/jpeg;base64,\(data.base64EncodedString())"
        }
        do {
            var url = baseURL
            url.append(path: "wingman/advise")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 60
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(WingmanAdvice.self, from: data)
            if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                error = "Daily wingman token budget reached. \(decoded.reason ?? "")"
                return
            }
            guard decoded.ok else {
                error = decoded.reason ?? "Wingman declined that request."
                return
            }
            replies = decoded.suggestedReplies ?? []
            lastUsage = decoded.usage
            if let usage = decoded.usage {
                let imageNote = decoded.sawImage == true ? " · screenshot billed" : ""
                usageText = String(
                    format: "%d left today · %d tokens this turn · $%.4f%@ ",
                    usage.requestsRemaining,
                    (usage.thisRequest?.inputTokens ?? 0) + (usage.thisRequest?.outputTokens ?? 0),
                    usage.thisRequest?.estimatedCostUsd ?? 0,
                    imageNote
                )
            }
            let advice = decoded.advice ?? ""
            messages.append(WingmanChatTurn(
                role: "assistant",
                content: advice,
                usageLine: usageText
            ))
        } catch {
            self.error = error.localizedDescription
        }
    }
}
