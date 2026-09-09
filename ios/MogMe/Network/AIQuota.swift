import Foundation

struct AIUsageSnapshot: Codable, Hashable {
    var requestsToday: Int
    var requestsRemaining: Int
    var tokensToday: Int
    var tokensRemaining: Int
}

@MainActor
final class AIQuota: ObservableObject {
    @Published private(set) var snapshot = AIUsageSnapshot(
        requestsToday: 0,
        requestsRemaining: 15,
        tokensToday: 0,
        tokensRemaining: 18_000
    )
    @Published var lastError: String?

    var line: String {
        "\(snapshot.requestsRemaining) AI turns left today · not unlimited"
    }

    var isExhausted: Bool {
        snapshot.requestsRemaining <= 0 || snapshot.tokensRemaining <= 0
    }

    func apply(_ usage: AIUsageSnapshot) {
        snapshot = usage
        if isExhausted {
            lastError = "Daily AI limit reached. Try again tomorrow."
        } else {
            lastError = nil
        }
    }

    func apply(from dict: [String: Any]) {
        let usage = dict["usage"] as? [String: Any] ?? dict
        apply(AIUsageSnapshot(
            requestsToday: int(usage["requestsToday"]),
            requestsRemaining: int(usage["requestsRemaining"]),
            tokensToday: int(usage["tokensToday"]),
            tokensRemaining: int(usage["tokensRemaining"])
        ))
    }

    func refresh(baseURL: URL, userKey: String) async {
        do {
            var url = baseURL
            url.append(path: "ai/usage")
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comps?.queryItems = [URLQueryItem(name: "userKey", value: userKey)]
            guard let final = comps?.url else { return }
            let (data, _) = try await URLSession.shared.data(from: final)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                apply(from: json)
            }
        } catch {
            // Keep the last known remaining count if the server is unreachable.
        }
    }

    private func int(_ value: Any?) -> Int {
        if let n = value as? Int { return n }
        if let n = value as? Double { return Int(n) }
        return 0
    }
}

extension WingmanUsage {
    var snapshot: AIUsageSnapshot {
        AIUsageSnapshot(
            requestsToday: requestsToday,
            requestsRemaining: requestsRemaining,
            tokensToday: tokensToday,
            tokensRemaining: tokensRemaining
        )
    }
}
