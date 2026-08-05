import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case schedule
    case workout
    case statistics
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab: AppTab = .schedule

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(
                "Schedule",
                systemImage: "calendar.circle.fill",
                value: .schedule
            ) {
                NavigationStack {
                    ScheduleHome()
                }
            }
            
            Tab(
                "Workout",
                systemImage: "figure.equestrian.sports.circle.fill",
                value: .workout
            ) {
                NavigationStack {
                    WorkoutHome()
                }
            }
            
            Tab(
                "Statistics",
                systemImage: "chart.pie.fill",
                value: .statistics
            ) {
                NavigationStack {
                    StatisticsHome()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ExerciseItem.self, WorkoutItem.self, WorkoutExerciseItem.self, RepeatItem.self, GoalItem.self, ScheduledWorkoutItem.self], inMemory: true)
}
