import SwiftUI

struct SocialView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                MogTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        NavigationLink { WingmanView() } label: {
                            MogCard {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "sparkle.magnifyingglass")
                                        .font(.title)
                                        .foregroundStyle(MogTheme.gold)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("AI Wingman").font(.headline)
                                        Text("Drop a chat screenshot or paste texts. Wingman evaluates the line, drafts replies, and remembers this person on-device.")
                                            .font(.subheadline)
                                            .foregroundStyle(MogTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(MogTheme.muted)
                                }
                            }
                        }
                        NavigationLink { CompanionView() } label: {
                            MogCard {
                                HStack {
                                    Image(systemName: "heart.fill").foregroundStyle(MogTheme.gold)
                                    Text("Companion chat")
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(MogTheme.muted)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Social")
            .crownToolbar()
        }
    }
}
