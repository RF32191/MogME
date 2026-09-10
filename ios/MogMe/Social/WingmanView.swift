import SwiftUI
import PhotosUI

struct WingmanView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreKitManager
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
        .crownToolbar()
        .onAppear {
            hydrateFromSelected()
            Task { await appState.aiQuota.refresh(baseURL: appState.apiBaseURL, userKey: appState.userId ?? appState.handle) }
        }
        .fullScreenCover(isPresented: $cameraOpen) {
            MealCameraView(
                onCapture: { image in
                    cameraOpen = false
                    Task { await attachAndAnalyze(image) }
                },
                onCancel: { cameraOpen = false }
            )
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item, let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await attachAndAnalyze(image)
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
                Text("Pick a live or library screenshot. Wingman describes the photo, then returns full analytics for the chat. Each image read spends tokens.")
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
            if service.messages.isEmpty && !service.hasAnalytics {
                MogCard {
                    Text("Choose a chat screenshot. You get an item description of what’s in the photo plus full analytics — tone, transcript, strategy, and token cost.")
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
            if service.hasAnalytics {
                WingmanPhotoAnalyticsCard(service: service, photo: chatImage ?? service.lastPhoto)
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
                    Text("Reading the photo and filling analytics…")
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
            if let attached = chatImage {
                HStack {
                    Image(uiImage: attached)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text(service.busy ? "Analyzing photo…" : "Screenshot attached — this turn bills vision tokens")
                        .font(.caption)
                        .foregroundStyle(MogTheme.gold)
                    Spacer()
                    Button("Remove") { chatImage = nil }
                }
            }
            HStack(alignment: .bottom) {
                TextField("Ask a follow-up, or add a line", text: $text, axis: .vertical)
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
                Button {
                    guard store.offerTokensIfNeeded(appState.aiQuota) else { return }
                    cameraOpen = true
                } label: {
                    Label("Live shot", systemImage: "camera.fill")
                }
                if appState.aiQuota.isExhausted {
                    Button {
                        store.showTokens = true
                    } label: {
                        Label("Library", systemImage: "photo")
                    }
                } else {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Library", systemImage: "photo")
                    }
                }
                Spacer()
            }
            .font(.caption)
            Text(service.usageText).font(.caption2).foregroundStyle(MogTheme.muted)
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

    private func attachAndAnalyze(_ image: UIImage) async {
        guard store.offerTokensIfNeeded(appState.aiQuota) else { return }
        savePartner()
        chatImage = image
        await service.advise(
            baseURL: appState.apiBaseURL,
            userKey: appState.userId ?? appState.handle,
            goal: goal,
            text: "Describe this photo in detail, then give full analytics of the chat: who is speaking, tone, what’s working, risks, and the next move.",
            image: image,
            memory: partners.selected
        )
        if let usage = service.lastUsage {
            appState.aiQuota.apply(usage.snapshot)
        }
        chatImage = nil
    }

    private func ask() async {
        guard store.offerTokensIfNeeded(appState.aiQuota) else { return }
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
        if let usage = service.lastUsage {
            appState.aiQuota.apply(usage.snapshot)
        }
    }
}

struct WingmanPhotoAnalyticsCard: View {
    @ObservedObject var service: WingmanService
    var photo: UIImage?

    var body: some View {
        MogCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Photo analysis").font(.headline)
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if !service.photoDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Item description").font(.caption.weight(.semibold)).foregroundStyle(MogTheme.muted)
                        Text(service.photoDescription)
                    }
                }
                if !service.tone.isEmpty {
                    Text("Tone: \(service.tone)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MogTheme.gold)
                }
                if !service.analysis.isEmpty {
                    Text(service.analysis)
                }
                if !service.transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("From the screenshot").font(.caption.bold())
                        Text(service.transcript).font(.footnote).foregroundStyle(MogTheme.muted)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    stat("Saw photo", service.sawImage ? "Yes" : "No")
                    stat("Tokens", "\(service.tokensThisTurn)")
                    stat("This turn", String(format: "$%.4f", service.costThisTurn))
                    stat("Left today", "\(service.requestsRemaining)")
                    stat("Token pool", "\(service.tokensRemaining)")
                    stat("Today $", String(format: "$%.4f", service.costToday))
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(label)
                .font(.caption2)
                .foregroundStyle(MogTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(MogTheme.goldSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
