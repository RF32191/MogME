import SwiftUI
import PhotosUI

struct DietView: View {
    @EnvironmentObject private var meals: MealStore
    @EnvironmentObject private var appState: AppState
    @StateObject private var model = DietSearchModel()
    @State private var cameraOpen = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var captured: UIImage?
    @State private var showResults = false

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
                                Text("Search by food name, or snap a package/label. Calories come from Open Food Facts and the on-device catalog — no AI estimates.")
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
                                    Button {
                                        cameraOpen = true
                                    } label: {
                                        Label("Photograph meal", systemImage: "camera.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    PhotosPicker(selection: $pickerItem, matching: .images) {
                                        Label("Library", systemImage: "photo")
                                    }
                                    .buttonStyle(.bordered)
                                }
                                if let captured {
                                    Image(uiImage: captured)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    Button("Find calories from this photo") {
                                        Task { await model.searchFromPhoto(captured) }
                                    }
                                    .buttonStyle(GoldButtonStyle())
                                }
                                if model.busy { ProgressView().tint(MogTheme.gold) }
                                if let err = model.error { Text(err).font(.footnote).foregroundStyle(.red) }
                            }
                        }

                        if !model.hits.isEmpty {
                            Text("Matches").font(.headline)
                            ForEach(model.hits) { hit in
                                Button {
                                    meals.log(hit: hit, image: captured)
                                    captured = nil
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
                                            Text(meal.source).font(.caption).foregroundStyle(MogTheme.muted)
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
            .fullScreenCover(isPresented: $cameraOpen) {
                MealCameraView { image in
                    captured = image
                    cameraOpen = false
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    captured = image
                }
            }
            .onChange(of: appState.pendingFoodQuery) { _, query in
                guard let query, !query.isEmpty else { return }
                model.query = query
                appState.pendingFoodQuery = nil
                Task { await model.searchByName() }
            }
        }
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
    private let lookup = FoodLookupService()

    func searchByName() async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            hits = try await lookup.search(query: query)
            if hits.isEmpty { error = "No matches. Try a simpler food name." }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func searchFromPhoto(_ image: UIImage) async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            hits = try await lookup.searchFromLabelImage(image)
            if hits.isEmpty {
                error = "Could not read a product name from the photo. Type the food name instead."
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
