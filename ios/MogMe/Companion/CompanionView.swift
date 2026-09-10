import SwiftUI

struct CompanionView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreKitManager
    @State private var name = "Avery"
    @State private var tone = "friend"
    @State private var draft = ""
    @State private var log: [String] = ["Say hi. History stays on-device; only the last turns go to the server."]
    @State private var busy = false

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    Picker("Tone", selection: $tone) {
                        Text("Friend").tag("friend")
                        Text("Support").tag("supportive")
                        Text("Flirty").tag("flirty")
                        Text("Romantic").tag("romantic")
                    }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(log, id: \.self) { line in
                            Text(line)
                                .padding(10)
                                .background(MogTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                if let err = appState.aiQuota.lastError {
                    Text(err).font(.footnote).foregroundStyle(.red)
                }
                HStack {
                    TextField("Message", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") { Task { await send() } }
                        .buttonStyle(GoldButtonStyle(enabled: !busy))
                        .frame(width: 90)
                        .disabled(busy)
                }
            }
            .padding(20)
        }
        .navigationTitle("Companion")
        .crownToolbar()
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard store.offerTokensIfNeeded(appState.aiQuota) else { return }
        draft = ""
        log.append("You: \(text)")
        busy = true
        defer { busy = false }
        struct Body: Encodable {
            struct Persona: Encodable {
                let name: String
                let age: Int
                let tone: String
            }
            let userKey: String
            let persona: Persona
            let text: String
        }
        struct Res: Decodable {
            let ok: Bool
            let reply: String
            let reason: String?
            let usage: AIUsageSnapshot?
        }
        do {
            let res: Res = try await APIClient(baseURL: appState.apiBaseURL).post(
                "companion/message",
                body: Body(
                    userKey: appState.userId ?? appState.handle,
                    persona: .init(name: name, age: 24, tone: tone),
                    text: text
                )
            )
            if let usage = res.usage { appState.aiQuota.apply(usage) }
            if res.ok {
                log.append("\(name): \(res.reply)")
            } else {
                if res.reason == "daily-request-cap" || res.reason == "daily-token-cap" {
                    store.showTokens = true
                } else {
                    log.append(res.reply.isEmpty ? (res.reason ?? "Blocked") : res.reply)
                }
            }
        } catch {
            log.append("Couldn't reach companion: \(error.localizedDescription)")
        }
    }
}
