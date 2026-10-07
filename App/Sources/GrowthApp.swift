import SwiftUI
import GrowthCore
import AppFeatures

@main
struct GrowthApp: App {
    @State private var repository: AppRepository = Self.makeRepository()

    var body: some Scene {
        WindowGroup {
            AppRootView(repository: repository, initialTab: Self.initialTab)
        }
    }

    /// Local-first storage. If the Application Support directory can't be created (very rare),
    /// fall back to in-memory storage so the app still opens; the save-error banner explains the situation.
    @MainActor
    private static func makeRepository() -> AppRepository {
        #if DEBUG
        // Screenshot harness: `-demoScenario teen|parent|starter|adult|concern|onboarding` uses synthetic data in memory.
        if let name = UserDefaults.standard.string(forKey: "demoScenario"), let scenario = DemoScenario(rawValue: name) {
            return AppRepository(store: InMemoryProfileStore(snapshot: scenario.snapshot()))
        }
        #endif
        if let store = try? FileProfileStore.defaultStore() {
            return AppRepository(store: store)
        }
        return AppRepository(store: InMemoryProfileStore())
    }

    private static var initialTab: AppTab {
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "initialTab"), let tab = AppTab(rawValue: name) { return tab }
        #endif
        return .home
    }
}
