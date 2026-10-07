import SwiftUI
import GrowthCore
import AppFeatures

@main
struct GrowthApp: App {
    @State private var repository: AppRepository = Self.makeRepository()

    var body: some Scene {
        WindowGroup {
            AppRootView(repository: repository)
        }
    }

    /// Local-first storage. If the Application Support directory can't be created (very rare),
    /// fall back to in-memory storage so the app still opens; the save-error banner explains the situation.
    @MainActor
    private static func makeRepository() -> AppRepository {
        if let store = try? FileProfileStore.defaultStore() {
            return AppRepository(store: store)
        }
        return AppRepository(store: InMemoryProfileStore())
    }
}
