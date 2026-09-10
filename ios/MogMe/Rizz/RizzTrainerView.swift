import SwiftUI

struct RizzTrainerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var goal = "open"
    @State private var difficulty = "medium"
    @State private var sessionId: String?
    @State private var persona = ""
    @State private var reply = "Pick a goal and start a practice date."
    @State private var tip = ""
    @State private var affection = 20
    @State private var draft = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Picker("Goal", selection: $goal) {
                    Text("Connect").tag("open")
                    Text("Number").tag("number")
                    Text("Date").tag("date")
                    Text("Recover").tag("recover")
                }
                .pickerStyle(.segmented)
                Picker("Difficulty", selection: $difficulty) {
                    Text("Easy").tag("easy")
                    Text("Medium").tag("medium")
                    Text("Hard").tag("hard")
                }
                .pickerStyle(.segmented)
                MogCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(persona.isEmpty ? "Rizz Trainer" : persona).font(.headline)
                        ProgressView(value: Double(affection), total: 100)
                            .tint(MogTheme.gold)
                        Text(reply)
                        if !tip.isEmpty {
                            Text("Coach: \(tip)").font(.footnote).foregroundStyle(MogTheme.gold)
                        }
                    }
                }
                TextField("Your line", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                HStack {
                    Button("Start") { Task { await start() } }
                        .buttonStyle(.bordered)
                    Button("Send") { Task { await send() } }
                        .buttonStyle(GoldButtonStyle(enabled: sessionId != nil && !busy))
                }
                Text(appState.aiQuota.tokenLine)
                    .font(.caption)
                    .foregroundStyle(MogTheme.muted)
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                Spacer()
            }
            .padding(20)
        }
        .navigationTitle("Rizz Trainer")
        .crownToolbar()
    }

    private var client: APIClient { APIClient(baseURL: appState.apiBaseURL) }

    private func start() async {
        busy = true
        defer { busy = false }
        do {
            let res: StartRes = try await client.post("rizz/practice/start", body: ["goal": goal, "difficulty": difficulty])
            sessionId = res.sessionId
            persona = res.persona.name
            affection = res.affection
            reply = "You're talking to \(res.persona.name). \(res.persona.bio)"
            tip = ""
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func send() async {
        guard let sessionId else { return }
        let text = draft
        draft = ""
        busy = true
        defer { busy = false }
        do {
            let res: TurnRes = try await client.post(
                "rizz/practice/message",
                body: ["sessionId": sessionId, "text": text, "userKey": appState.userId ?? appState.handle]
            )
            if let usage = res.usage { appState.aiQuota.apply(usage) }
            if res.ok == false, res.reason == "daily-request-cap" || res.reason == "daily-token-cap" {
                error = "Daily AI limit reached. Rizz Trainer is not unlimited."
                return
            }
            reply = res.reply ?? reply
            tip = res.tip ?? ""
            affection = res.affection
            if res.won == true { tip = "Closed it. \(tip)" }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private struct StartRes: Decodable {
        let sessionId: String
        let persona: Persona
        let affection: Int
        struct Persona: Decodable { let name: String; let bio: String }
    }

    private struct TurnRes: Decodable {
        let ok: Bool?
        let reason: String?
        let reply: String?
        let tip: String?
        let affection: Int
        let won: Bool?
        let usage: AIUsageSnapshot?
    }
}
