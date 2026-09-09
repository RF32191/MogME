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
    @State private var cameraOpen = false
    @State private var name = ""
    @State private var notes = ""
    @State private var style = ""
    @State private var factDraft = ""

    var body: some View {
        ZStack {
            MogTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        memoryCard
                        conversation
                    }
                    .padding(20)
                }
                composer
            }
        }
        .navigationTitle("AI Wingman")
        .onAppear { hydrateFromSelected() }
        .fullScreenCover(isPresented: $cameraOpen) {
            MealCameraView(
                onCapture: { image in
                    chatImage = image
                    cameraOpen = false
                },
                onCancel: { cameraOpen = false }
            )
        }
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

    private var memoryCard: some View {
        MogCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Who you're texting").font(.headline)
                Text("Saved on this iPhone. Each screenshot you send is a real vision turn and spends tokens.")
                    .font(.footnote)
                    .foregroundStyle(MogTheme.muted)
                TextField("Name", text: $name).textFieldStyle(.roundedBorder)
                TextField("Texting style", text: $style).textFieldStyle(.roundedBorder)
                TextField("Notes", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                HStack {
                    TextField("Add a fact", text: $factDraft).textFieldStyle(.roundedBorder)
                    Button("Save") { savePartner() }.buttonStyle(.bordered)
                }
            }
        }
    }

    private var conversation: some View {
        VStack(alignment: .leading, spacing: 10) {
            if service.messages.isEmpty {
                MogCard {
                    Text("Drop a live screenshot of the chat. Wingman reads the bubbles, answers in this thread, and the turn is billed.")
                        .foregroundStyle(MogTheme.muted)
                }
            }
            ForEach(service.messages) { message in
                VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 6) {
                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Text(message.content)
                        .padding(10)
                        .background(message.role == "user" ? MogTheme.goldSoft : MogTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    if let usage = message.usageLine {
                        Text(usage).font(.caption2).foregroundStyle(MogTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
            }
            if !service.analysis.isEmpty {
                MogCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI analysis").font(.headline)
                        if !service.tone.isEmpty {
                            Text("Tone: \(service.tone)").font(.caption).foregroundStyle(MogTheme.gold)
                        }
                        Text(service.analysis)
                        if !service.transcript.isEmpty {
                            Text("From the screenshot").font(.caption.bold()).padding(.top, 4)
                            Text(service.transcript).font(.footnote).foregroundStyle(MogTheme.muted)
                        }
                    }
                }
            }
            if !service.replies.isEmpty {
                Text("Try sending").font(.subheadline.bold())
                ForEach(service.replies, id: \.self) { reply in
                    Button {
                        text = reply
                    } label: {
                        Text("“\(reply)”")
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MogTheme.goldSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            if service.busy {
                HStack(spacing: 8) {
                    ProgressView().tint(MogTheme.gold)
                    Text("Reading the chat and spending tokens…")
                        .font(.footnote)
                        .foregroundStyle(MogTheme.muted)
                }
            }
            if let err = service.error {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Goal", selection: $goal) {
                Text("Evaluate").tag("evaluate")
                Text("Reply").tag("reply")
                Text("Strategy").tag("strategy")
            }
            .pickerStyle(.segmented)
            if let chatImage {
                HStack {
                    Image(uiImage: chatImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Screenshot attached — this turn bills vision tokens")
                        .font(.caption)
                        .foregroundStyle(MogTheme.gold)
                    Spacer()
                    Button("Remove") { chatImage = nil }
                }
            }
            HStack(alignment: .bottom) {
                TextField("Ask about the screenshot or paste a line", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
                Button {
                    Task { await ask() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(service.busy ? MogTheme.muted : MogTheme.gold)
                }
                .disabled(service.busy)
            }
            HStack {
                Button { cameraOpen = true } label: {
                    Label("Live shot", systemImage: "camera.fill")
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Library", systemImage: "photo")
                }
                Spacer()
                Text(service.usageText).font(.caption2).foregroundStyle(MogTheme.muted)
            }
            .font(.caption)
        }
        .padding(12)
        .background(MogTheme.card)
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
        let outgoing = text
        let image = chatImage
        text = ""
        chatImage = nil
        await service.advise(
            baseURL: appState.apiBaseURL,
            userKey: appState.userId ?? appState.handle,
            goal: goal,
            text: outgoing,
            image: image,
            memory: partners.selected
        )
    }
}
