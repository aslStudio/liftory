import SwiftUI
import SwiftData

@main
struct GymTrackerApp: App {
    @StateObject private var premiumStore = PremiumStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ExerciseItem.self,
            WorkoutItem.self,
            WorkoutExerciseItem.self,
            RepeatItem.self,
            GoalItem.self,
            ScheduledWorkoutItem.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: PremiumStore.cachedIsPremium ? .private("iCloud.vladAstahov.gymTracker.GymTracker") : .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(premiumStore)
        }
        .modelContainer(sharedModelContainer)
    }
}
