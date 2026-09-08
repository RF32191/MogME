import SwiftUI

struct CompanionView: View {
    @EnvironmentObject private var appState: AppState
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
                HStack {
                    TextField("Message", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") { Task { await send() } }
                        .buttonStyle(GoldButtonStyle(enabled: !busy))
                        .frame(width: 90)
                }
            }
            .padding(20)
        }
        .navigationTitle("Companion")
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
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
            let persona: Persona
            let text: String
        }
        struct Res: Decodable { let ok: Bool; let reply: String }
        do {
            let res: Res = try await APIClient(baseURL: appState.apiBaseURL).post(
                "companion/message",
                body: Body(persona: .init(name: name, age: 24, tone: tone), text: text)
            )
            log.append("\(name): \(res.reply)")
        } catch {
            log.append("Couldn't reach companion: \(error.localizedDescription)")
        }
    }
}
