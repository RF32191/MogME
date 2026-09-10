import Foundation

struct AIUsageSnapshot: Codable, Hashable {
    var requestsToday: Int
    var requestsRemaining: Int
    var tokensToday: Int
    var tokensRemaining: Int
    var dailyTokenCap: Int
    var dailyRequestCap: Int

    enum CodingKeys: String, CodingKey {
        case requestsToday, requestsRemaining, tokensToday, tokensRemaining
        case dailyTokenCap, dailyRequestCap
    }

    init(
        requestsToday: Int,
        requestsRemaining: Int,
        tokensToday: Int,
        tokensRemaining: Int,
        dailyTokenCap: Int = 18_000,
        dailyRequestCap: Int = 15
    ) {
        self.requestsToday = requestsToday
        self.requestsRemaining = requestsRemaining
        self.tokensToday = tokensToday
        self.dailyTokenCap = dailyTokenCap
        self.dailyRequestCap = dailyRequestCap
        self.tokensRemaining = tokensRemaining
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        requestsToday = try box.decodeIfPresent(Int.self, forKey: .requestsToday) ?? 0
        requestsRemaining = try box.decodeIfPresent(Int.self, forKey: .requestsRemaining) ?? 0
        tokensToday = try box.decodeIfPresent(Int.self, forKey: .tokensToday) ?? 0
        tokensRemaining = try box.decodeIfPresent(Int.self, forKey: .tokensRemaining) ?? 0
        dailyTokenCap = try box.decodeIfPresent(Int.self, forKey: .dailyTokenCap) ?? 18_000
        dailyRequestCap = try box.decodeIfPresent(Int.self, forKey: .dailyRequestCap) ?? 15
    }
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
    @Published private(set) var purchasedTokens = 0

    var line: String { tokenLine }

    var tokenLine: String {
        let total = snapshot.tokensRemaining + purchasedTokens
        return "\(total.formatted()) tokens left · buy more in Lifetime"
    }

    var walletDetail: String {
        "Daily \(snapshot.tokensRemaining.formatted()) + purchased \(purchasedTokens.formatted()) · used \(snapshot.tokensToday.formatted()) today"
    }

    var isExhausted: Bool {
        snapshot.tokensRemaining + purchasedTokens <= 0
    }

    func addPurchased(_ amount: Int) {
        purchasedTokens += max(0, amount)
    }

    func syncPurchased(_ amount: Int) {
        purchasedTokens = max(purchasedTokens, amount)
    }

    func apply(_ usage: AIUsageSnapshot) {
        snapshot = usage
        if isExhausted {
            lastError = "AI token pool is empty for today. Not unlimited."
        } else {
            lastError = nil
        }
    }

    func apply(from dict: [String: Any]) {
        let usage = dict["usage"] as? [String: Any] ?? dict
        let remaining = dict["remaining"] as? [String: Any]
        apply(AIUsageSnapshot(
            requestsToday: int(usage["requestsToday"]),
            requestsRemaining: int(usage["requestsRemaining"] ?? remaining?["requests"]),
            tokensToday: int(usage["tokensToday"]),
            tokensRemaining: int(usage["tokensRemaining"] ?? remaining?["tokens"]),
            dailyTokenCap: int(usage["dailyTokenCap"] ?? dict["dailyTokenCap"], fallback: 18_000),
            dailyRequestCap: int(usage["dailyRequestCap"] ?? dict["dailyRequestCap"], fallback: 15)
        ))
        syncPurchased(int(usage["purchasedTokens"]))
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

    private func int(_ value: Any?, fallback: Int = 0) -> Int {
        if let n = value as? Int { return n }
        if let n = value as? Double { return Int(n) }
        return fallback
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
