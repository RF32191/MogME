import SwiftUI

struct FoodAnalysisCard: View {
    let hit: FoodHit
    var photoDescription: String = ""
    var photo: UIImage?
    var googleImages: [GoogleImageMatch] = []
    var identifiedByGoogle = false

    var body: some View {
        MogCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Item analysis").font(.headline)
                if identifiedByGoogle {
                    Text("Identified with Google Images")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MogTheme.gold)
                }
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Text(hit.name)
                    .font(.title3.bold())
                    .foregroundStyle(MogTheme.gold)
                if let brand = hit.brand, !brand.isEmpty {
                    Text(brand).font(.subheadline).foregroundStyle(MogTheme.muted)
                }
                if !photoDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Item description").font(.caption.weight(.semibold)).foregroundStyle(MogTheme.muted)
                        Text(photoDescription)
                            .font(.subheadline)
                    }
                }
                if !hit.headline.isEmpty {
                    Text(hit.headline).font(.footnote).foregroundStyle(MogTheme.muted)
                }
                if !googleImages.isEmpty {
                    Text("Similar Google Images").font(.caption.weight(.semibold)).foregroundStyle(MogTheme.muted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(googleImages) { match in
                                VStack(alignment: .leading, spacing: 4) {
                                    AsyncImage(url: match.thumbURL ?? match.imageURL) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().scaledToFill()
                                        default:
                                            Color.white.opacity(0.06)
                                        }
                                    }
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    Text(match.title)
                                        .font(.caption2)
                                        .lineLimit(2)
                                        .frame(width: 84, alignment: .leading)
                                }
                            }
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    stat("Calories", "\(Int(hit.calories))")
                    stat("Protein", grams(hit.protein))
                    stat("Carbs", grams(hit.carbs))
                    stat("Fat", grams(hit.fat))
                    stat("Fiber", grams(hit.fiber))
                    stat("Sugars", grams(hit.sugars))
                    stat("Sodium", hit.sodium.map { "\(Int($0)) mg" } ?? "—")
                    stat("Serving", hit.serving)
                    stat("Source", hit.source)
                }
            }
        }
    }

    private func grams(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded())) g" } ?? "—"
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
