import SwiftUI
import PhotosUI

struct WingmanView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var partners: PartnerMemoryStore
    @StateObject private var service = WingmanService()
    @State private var goal = "evaluate"
    @State private var text = ""
    @State private var chatImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var name = ""
    @State private var notes = ""
    @State private var style = ""
    @State private var factDraft = ""

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    MogCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Who you're texting").font(.headline)
                            Text("Saved only on this iPhone. The server gets a short summary per request.")
                                .font(.footnote)
                                .foregroundStyle(MogTheme.muted)
                            TextField("Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                            TextField("Texting style (dry, playful, slow…)", text: $style)
                                .textFieldStyle(.roundedBorder)
                            TextField("Notes", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                            HStack {
                                TextField("Add a fact", text: $factDraft)
                                    .textFieldStyle(.roundedBorder)
                                Button("Save person") { savePartner() }
                                    .buttonStyle(.bordered)
                            }
                            if let selected = partners.selected {
                                Text("Active: \(selected.name.isEmpty ? "Unnamed" : selected.name) · \(selected.facts.count) facts")
                                    .font(.caption)
                                    .foregroundStyle(MogTheme.gold)
                            }
                        }
                    }

                    MogCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Goal", selection: $goal) {
                                Text("Evaluate").tag("evaluate")
                                Text("Draft replies").tag("reply")
                                Text("Strategy").tag("strategy")
                            }
                            .pickerStyle(.segmented)
                            TextField("Paste the last texts, or describe the moment", text: $text, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(4...8)
                            HStack {
                                PhotosPicker(selection: $pickerItem, matching: .images) {
                                    Label("Chat screenshot", systemImage: "text.below.photo")
                                }
                                if chatImage != nil {
                                    Button("Clear photo") { chatImage = nil }
                                }
                            }
                            if let chatImage {
                                Image(uiImage: chatImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            Button("Ask Wingman") {
                                Task { await ask() }
                            }
                            .buttonStyle(GoldButtonStyle(enabled: !service.busy))
                            Text(service.usageText).font(.caption).foregroundStyle(MogTheme.muted)
                            if service.busy { ProgressView().tint(MogTheme.gold) }
                            if let err = service.error { Text(err).font(.footnote).foregroundStyle(.red) }
                        }
                    }

                    if !service.advice.isEmpty {
                        MogCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Advice").font(.headline)
                                Text(service.advice)
                                if !service.replies.isEmpty {
                                    Text("Try sending").font(.subheadline.bold()).padding(.top, 6)
                                    ForEach(service.replies, id: \.self) { reply in
                                        Text("“\(reply)”")
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(MogTheme.goldSoft)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("AI Wingman")
        .onAppear { hydrateFromSelected() }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                chatImage = UIImage(data: data)
            }
        }
        .onChange(of: appState.pendingWingmanPrompt) { _, prompt in
            guard let prompt, !prompt.isEmpty else { return }
            text = prompt
            appState.pendingWingmanPrompt = nil
            Task { await ask() }
        }
    }

    private func hydrateFromSelected() {
        guard let selected = partners.selected else { return }
        name = selected.name
        notes = selected.notes
        style = selected.style
    }

    private func savePartner() {
        if var current = partners.selected {
            current.name = name
            current.notes = notes
            current.style = style
            if !factDraft.trimmingCharacters(in: .whitespaces).isEmpty {
                current.facts.append(factDraft)
                factDraft = ""
            }
            partners.update(current)
        } else {
            var blank = PartnerProfile.blank()
            blank.name = name
            blank.notes = notes
            blank.style = style
            if !factDraft.isEmpty { blank.facts = [factDraft]; factDraft = "" }
            partners.add(blank)
        }
    }

    private func ask() async {
        savePartner()
        await service.advise(
            baseURL: appState.apiBaseURL,
            userKey: appState.userId ?? appState.handle,
            goal: goal,
            text: text,
            image: chatImage,
            memory: partners.selected
        )
    }
}
