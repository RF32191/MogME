import SwiftUI

struct MogOffView: View {
    @EnvironmentObject private var appState: AppState
    @State private var status = "Sign in, then queue. Face images stay distorted on-device before upload."
    @State private var userId = ""

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                MogCard {
                    Text(status)
                }
                Button("Sign in & remember ID") { Task { await signIn() } }
                    .buttonStyle(GoldButtonStyle())
                Text("WebSocket matchmaking lives at \(appState.apiBaseURL.absoluteString.replacingOccurrences(of: "https", with: "wss"))/ws")
                    .font(.footnote)
                    .foregroundStyle(MogTheme.muted)
                Spacer()
            }
            .padding(20)
        }
        .navigationTitle("Mog-Off")
        .crownToolbar()
    }

    private func signIn() async {
        struct Body: Encodable { let handle: String }
        struct Res: Decodable {
            let user: User
            struct User: Decodable { let id: String; let handle: String }
        }
        do {
            let res: Res = try await APIClient(baseURL: appState.apiBaseURL).post("auth/signin", body: Body(handle: appState.handle))
            userId = res.user.id
            appState.userId = res.user.id
            status = "Signed in as \(res.user.handle). Queue from a device build to play live rounds."
        } catch {
            status = error.localizedDescription
        }
    }
}
