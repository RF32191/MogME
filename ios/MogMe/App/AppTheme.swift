import SwiftUI

enum MogTheme {
    static let gold = Color(red: 0.831, green: 0.686, blue: 0.216)
    static let goldSoft = Color(red: 0.831, green: 0.686, blue: 0.216).opacity(0.16)
    static let bg = Color(red: 0.055, green: 0.055, blue: 0.07)
    static let card = Color(red: 0.11, green: 0.11, blue: 0.14)
    static let cardStroke = Color.white.opacity(0.08)
    static let text = Color.white
    static let muted = Color.white.opacity(0.62)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.09, green: 0.08, blue: 0.06), bg],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct GoldButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(enabled ? Color.black : Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(enabled ? MogTheme.gold : MogTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct MogCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MogTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MogTheme.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
