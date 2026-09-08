import SwiftUI

@main
struct MogMeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var store = StoreKitManager()
    @StateObject private var meals = MealStore()
    @StateObject private var partners = PartnerMemoryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(store)
                .environmentObject(meals)
                .environmentObject(partners)
                .preferredColorScheme(.dark)
                .task {
                    await store.load()
                    appState.bootstrap()
                }
        }
    }
}
