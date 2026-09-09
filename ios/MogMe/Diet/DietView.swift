import SwiftUI
import PhotosUI

struct DietView: View {
    @EnvironmentObject private var meals: MealStore
    @EnvironmentObject private var appState: AppState
    @StateObject private var model = DietSearchModel()
    @State private var cameraOpen = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                MogTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        MogCard {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Today").font(.subheadline).foregroundStyle(MogTheme.muted)
                                    Text("\(Int(meals.todayCalories)) kcal")
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundStyle(MogTheme.gold)
                                }
                                Spacer()
                                Image(systemName: "leaf.fill").foregroundStyle(MogTheme.gold).font(.title)
                            }
                        }

                        MogCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Look up calories").font(.headline)
                                Text("Take a live photo or search by name. We describe the plate, you can correct it, then calories come from Open Food Facts — not an AI guess.")
                                    .font(.footnote)
                                    .foregroundStyle(MogTheme.muted)
                                HStack {
                                    TextField("e.g. chicken rice bowl", text: $model.query)
                                        .textFieldStyle(.roundedBorder)
                                        .textInputAutocapitalization(.never)
                                    Button("Search") { Task { await model.searchByName() } }
                                        .buttonStyle(GoldButtonStyle(enabled: !model.busy))
                                        .frame(width: 110)
                                }
                                HStack(spacing: 10) {
                                    Button { cameraOpen = true } label: {
                                        Label("Live photo", systemImage: "camera.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    PhotosPicker(selection: $pickerItem, matching: .images) {
                                        Label("Library", systemImage: "photo")
                                    }
                                    .buttonStyle(.bordered)
                                }
                                if let captured = model.captured {
                                    mealPhotoCard(captured)
                                }
                                if let err = model.error { Text(err).font(.footnote).foregroundStyle(.red) }
                            }
                        }

                        if let top = model.hits.first {
                            analysisCard(top)
                        }

                        if !model.hits.isEmpty {
                            Text("Matches").font(.headline)
                            ForEach(model.hits) { hit in
                                Button {
                                    meals.log(hit: hit, image: model.captured, note: model.description)
                                    model.resetPhoto()
                                } label: {
                                    foodRow(hit)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !meals.meals.isEmpty {
                            Text("Saved locally").font(.headline)
                            ForEach(meals.meals.prefix(20)) { meal in
                                MogCard {
                                    HStack(alignment: .top, spacing: 12) {
                                        if let img = meals.image(for: meal) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 56, height: 56)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(meal.name).font(.headline)
                                            Text("\(Int(meal.calories)) kcal · \(meal.serving)")
                                                .font(.subheadline)
                                                .foregroundStyle(MogTheme.muted)
                                            if let note = meal.note, !note.isEmpty {
                                                Text(note).font(.caption).foregroundStyle(MogTheme.gold)
                                            }
                                        }
                                        Spacer()
                                        Button(role: .destructive) { meals.delete(meal) } label: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Diet")
            .crownToolbar()
            .fullScreenCover(isPresented: $cameraOpen) {
                MealCameraView(
                    onCapture: { image in
                        cameraOpen = false
                        Task { await model.acceptPhoto(image) }
                    },
                    onCancel: { cameraOpen = false }
                )
            }
            .onChange(of: pickerItem) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    await model.acceptPhoto(image)
                }
            }
            .onAppear { model.setAPI(appState.apiBaseURL) }
            .onChange(of: appState.pendingFoodQuery) { _, query in
                guard let query, !query.isEmpty else { return }
                model.query = query
                appState.pendingFoodQuery = nil
                Task { await model.searchByName() }
            }
        }
    }

    private func mealPhotoCard(_ captured: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Image(uiImage: captured)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                if model.busy {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.55))
                    VStack(spacing: 10) {
                        ProgressView().tint(MogTheme.gold).scaleEffect(1.3)
                        Text(model.loadingMessage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            Text("What we see — edit if it's wrong")
                .font(.caption)
                .foregroundStyle(MogTheme.muted)
            TextField("Describe the food", text: $model.description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                Button("Retake") { cameraOpen = true }
                    .buttonStyle(.bordered)
                Button("Use this description") {
                    Task { await model.searchFromDescription() }
                }
                .buttonStyle(GoldButtonStyle(enabled: !model.busy && !model.description.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
    }

    private func analysisCard(_ hit: FoodHit) -> some View {
        MogCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Food analysis").font(.headline)
                Text(hit.name).font(.title3.bold()).foregroundStyle(MogTheme.gold)
                Text(hit.headline).font(.subheadline)
                HStack {
                    macro("kcal", "\(Int(hit.calories))")
                    macro("P", hit.protein.map { "\(Int($0))g" } ?? "—")
                    macro("C", hit.carbs.map { "\(Int($0))g" } ?? "—")
                    macro("F", hit.fat.map { "\(Int($0))g" } ?? "—")
                }
                Text("\(hit.serving) · \(hit.source)").font(.caption).foregroundStyle(MogTheme.muted)
            }
        }
    }

    private func macro(_ label: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(MogTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func foodRow(_ hit: FoodHit) -> some View {
        MogCard {
            HStack(spacing: 12) {
                AsyncImage(url: hit.imageURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color.white.opacity(0.06)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(hit.name).font(.headline).foregroundStyle(.white)
                    if let brand = hit.brand { Text(brand).font(.caption).foregroundStyle(MogTheme.muted) }
                    Text("\(Int(hit.calories)) kcal / \(hit.serving) · \(hit.source)")
                        .font(.caption)
                        .foregroundStyle(MogTheme.gold)
                }
                Spacer()
                Image(systemName: "plus.circle.fill").foregroundStyle(MogTheme.gold)
            }
        }
    }
}

@MainActor
final class DietSearchModel: ObservableObject {
    @Published var query = ""
    @Published var hits: [FoodHit] = []
    @Published var busy = false
    @Published var error: String?
    @Published var captured: UIImage?
    @Published var description = ""
    @Published var loadingMessage = "Reading your meal…"
    private let lookup = FoodLookupService()

    func setAPI(_ url: URL) {
        Task { await lookup.use(apiBase: url) }
    }

    func resetPhoto() {
        captured = nil
        description = ""
        hits = []
        error = nil
        loadingMessage = "Reading your meal…"
    }

    func acceptPhoto(_ image: UIImage) async {
        captured = image
        hits = []
        error = nil
        description = ""
        busy = true
        loadingMessage = "Reading the live photo…"
        defer { busy = false }
        let read = await lookup.readMealPhoto(image)
        description = read.description.isEmpty ? read.suggestedName : read.description
        query = read.suggestedName
        loadingMessage = "Looking up calories…"
        do {
            let terms = description.isEmpty ? read.suggestedName : description
            hits = try await lookup.searchFromDescription(terms)
            if hits.isEmpty {
                error = "No calorie match yet. Correct the description and tap Use this description."
            }
        } catch {
            self.error = error.localizedDescription
        }
        loadingMessage = "Reading your meal…"
    }

    func searchByName() async {
        busy = true
        error = nil
        loadingMessage = "Searching foods…"
        defer {
            busy = false
            loadingMessage = "Reading your meal…"
        }
        do {
            hits = try await lookup.search(query: query)
            if hits.isEmpty { error = "No matches. Try a simpler food name." }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func searchFromDescription() async {
        busy = true
        error = nil
        loadingMessage = "Updating calories from your description…"
        defer {
            busy = false
            loadingMessage = "Reading your meal…"
        }
        do {
            hits = try await lookup.searchFromDescription(description)
            if hits.isEmpty { error = "No matches for that description. Try a shorter food name." }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
