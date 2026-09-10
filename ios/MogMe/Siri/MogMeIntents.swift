import AppIntents
import SwiftUI

struct MogMeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchFoodCaloriesIntent(),
            phrases: [
                "Look up calories for \(\.$food) in \(.applicationName)",
                "How many calories in \(\.$food) in \(.applicationName)",
            ],
            shortTitle: "Food calories",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: StartJapaneseWalkIntent(),
            phrases: [
                "Start Japanese walking in \(.applicationName)",
                "Start my interval walk in \(.applicationName)",
            ],
            shortTitle: "Japanese walk",
            systemImageName: "figure.walk"
        )
        AppShortcut(
            intent: StartIntervalCardioIntent(),
            phrases: [
                "Start interval cardio in \(.applicationName)",
            ],
            shortTitle: "Interval cardio",
            systemImageName: "figure.run"
        )
        AppShortcut(
            intent: AskWingmanIntent(),
            phrases: [
                "Ask Wingman in \(.applicationName) \(\.$prompt)",
                "Coach this text in \(.applicationName) \(\.$prompt)",
            ],
            shortTitle: "Ask Wingman",
            systemImageName: "bubble.left"
        )
    }
}

struct MogMeSpokenText: AppEntity, Sendable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Text")
    static var defaultQuery = MogMeSpokenTextQuery()

    var id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

struct MogMeSpokenTextQuery: EntityStringQuery {
    func entities(for identifiers: [MogMeSpokenText.ID]) async throws -> [MogMeSpokenText] {
        identifiers.map { MogMeSpokenText(id: $0) }
    }

    func entities(matching string: String) async throws -> [MogMeSpokenText] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return [MogMeSpokenText(id: trimmed)]
    }

    func suggestedEntities() async throws -> [MogMeSpokenText] {
        ["chicken", "rice", "apple", "what should I text back"].map { MogMeSpokenText(id: $0) }
    }
}

struct SearchFoodCaloriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Search food calories"
    static var description = IntentDescription("Look up calories by food name. No AI — Open Food Facts plus the on-device catalog.")
    static var openAppWhenRun = true

    @Parameter(title: "Food")
    var food: MogMeSpokenText

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(name: .mogMeOpenFood, object: food.id)
        return .result(dialog: "Opening Diet to look up \(food.id).")
    }
}

struct StartJapaneseWalkIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Japanese walking"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(name: .mogMeStartWalk, object: nil)
        return .result(dialog: "Starting Japanese walking.")
    }
}

struct StartIntervalCardioIntent: AppIntent {
    static var title: LocalizedStringResource = "Start interval cardio"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(name: .mogMeStartCardio, object: nil)
        return .result(dialog: "Starting interval cardio.")
    }
}

struct AskWingmanIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Wingman"
    static var openAppWhenRun = true

    @Parameter(title: "Prompt")
    var prompt: MogMeSpokenText

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(name: .mogMeWingman, object: prompt.id)
        return .result(dialog: "Opening Wingman with that text.")
    }
}

extension Notification.Name {
    static let mogMeOpenFood = Notification.Name("mogme.openFood")
    static let mogMeStartWalk = Notification.Name("mogme.startWalk")
    static let mogMeStartCardio = Notification.Name("mogme.startCardio")
    static let mogMeWingman = Notification.Name("mogme.wingman")
}
