import SwiftUI
import SwiftData

struct CreateWorkout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ExerciseItem.name) private var exercises: [ExerciseItem]

    @State private var name = ""
    @State private var selectedExercises: [WorkoutExerciseSelection] = []

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedExerciseItems: [WorkoutExerciseItem] {
        selectedExercises.enumerated().compactMap { index, selection in
            guard let exercise = exercises.first(where: { $0.id == selection.exerciseID }) else {
                return nil
            }

            return WorkoutExerciseItem(
                exercise: exercise,
                sortOrder: index
            )
        }
    }

    var body: some View {
        WorkoutForm(
            name: $name,
            selectedExercises: $selectedExercises
        )
        .navigationTitle("Create Workout")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveWorkout()
                }
                .disabled(trimmedName.isEmpty || selectedExercises.isEmpty)
            }
        }
    }

    private func saveWorkout() {
        let workout = WorkoutItem(
            name: trimmedName,
            durations: [],
            exerciseItems: selectedExerciseItems
        )

        modelContext.insert(workout)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save workout: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        CreateWorkout()
    }
    .modelContainer(for: [ExerciseItem.self, WorkoutItem.self, WorkoutExerciseItem.self, RepeatItem.self, GoalItem.self, ScheduledWorkoutItem.self], inMemory: true)
}
