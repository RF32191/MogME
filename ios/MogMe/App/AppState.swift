import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable {
        case home, diet, train, social, play
    }

    @Published var tab: Tab = .home
    @Published var handle: String
    @Published var userId: String?
    @Published var pendingFoodQuery: String?
    @Published var pendingWalkStart = false
    @Published var pendingCardioStart = false
    @Published var pendingWingmanPrompt: String?

    private let defaults = UserDefaults.standard

    init() {
        handle = defaults.string(forKey: "mogme.handle") ?? "mogger"
    }

    var apiBaseURL: URL {
        if let raw = defaults.string(forKey: "mogme.apiBase"),
           let url = URL(string: raw),
           !raw.isEmpty {
            return url
        }
        return URL(string: "https://mogme-production.up.railway.app")!
    }

    func bootstrap() {
        if handle.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            handle = "mogger"
        }
        defaults.set(handle, forKey: "mogme.handle")
        listenForSiri()
    }

    private func listenForSiri() {
        let center = NotificationCenter.default
        center.addObserver(forName: .mogMeOpenFood, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                self?.pendingFoodQuery = note.object as? String
                self?.tab = .diet
            }
        }
        center.addObserver(forName: .mogMeStartWalk, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.pendingWalkStart = true
                self?.tab = .train
            }
        }
        center.addObserver(forName: .mogMeStartCardio, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.pendingCardioStart = true
                self?.tab = .train
            }
        }
        center.addObserver(forName: .mogMeWingman, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                self?.pendingWingmanPrompt = note.object as? String
                self?.tab = .social
            }
        }
    }

    func setHandle(_ value: String) {
        let trimmed = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        handle = trimmed.count >= 2 ? trimmed : "mogger"
        defaults.set(handle, forKey: "mogme.handle")
    }

    func setAPIBase(_ value: String) {
        defaults.set(value, forKey: "mogme.apiBase")
        objectWillChange.send()
    }
}
