import Foundation

struct PartnerProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var style: String
    var facts: [String]
    var doNots: [String]
    var lastTopics: [String]
    var updatedAt: Date

    static func blank() -> PartnerProfile {
        PartnerProfile(id: UUID(), name: "", notes: "", style: "", facts: [], doNots: [], lastTopics: [], updatedAt: Date())
    }

    var payload: PartnerMemoryPayload {
        PartnerMemoryPayload(
            name: name,
            notes: notes,
            style: style,
            facts: Array(facts.prefix(8)),
            doNots: Array(doNots.prefix(6)),
            lastTopics: Array(lastTopics.prefix(6))
        )
    }
}

struct PartnerMemoryPayload: Codable, Hashable {
    var name: String
    var notes: String
    var style: String
    var facts: [String]
    var doNots: [String]
    var lastTopics: [String]
}

@MainActor
final class PartnerMemoryStore: ObservableObject {
    @Published var partners: [PartnerProfile] = []
    @Published var selectedID: UUID?

    private let url: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = docs.appendingPathComponent("partners.json")
        load()
        if selectedID == nil { selectedID = partners.first?.id }
    }

    var selected: PartnerProfile? {
        partners.first { $0.id == selectedID }
    }

    func add(_ partner: PartnerProfile) {
        partners.insert(partner, at: 0)
        selectedID = partner.id
        persist()
    }

    func update(_ partner: PartnerProfile) {
        if let idx = partners.firstIndex(where: { $0.id == partner.id }) {
            var next = partner
            next.updatedAt = Date()
            partners[idx] = next
            persist()
        }
    }

    func delete(_ partner: PartnerProfile) {
        partners.removeAll { $0.id == partner.id }
        if selectedID == partner.id { selectedID = partners.first?.id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        partners = (try? JSONDecoder().decode([PartnerProfile].self, from: data)) ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(partners) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
