import SwiftUI
import SwiftData

struct EditWorkout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ExerciseItem.name) private var exercises: [ExerciseItem]

    let workout: WorkoutItem

    @State private var name: String
    @State private var selectedExercises: [WorkoutExerciseSelection]

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

    init(workout: WorkoutItem) {
        self.workout = workout
        _name = State(initialValue: workout.name)
        _selectedExercises = State(
            initialValue: workout.exerciseItems
                .sorted { $0.sortOrder < $1.sortOrder }
                .compactMap { item in
                    guard let exercise = item.exercise else {
                        return nil
                    }

                    return WorkoutExerciseSelection(exerciseID: exercise.id)
                }
        )
    }

    var body: some View {
        WorkoutForm(
            name: $name,
            selectedExercises: $selectedExercises
        )
        .navigationTitle("Edit Workout")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
                    .disabled(selectedExercises.count < 2)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveWorkout()
                }
                .disabled(trimmedName.isEmpty || selectedExercises.isEmpty)
            }
        }
    }

    private func saveWorkout() {
        for exerciseItem in workout.exerciseItems {
            modelContext.delete(exerciseItem)
        }

        workout.name = trimmedName
        workout.exerciseItems = selectedExerciseItems

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
        EditWorkout(
            workout: WorkoutItem(
                name: "Workout",
                durations: [],
                exerciseItems: []
            )
        )
    }
    .modelContainer(for: [ExerciseItem.self, WorkoutItem.self, WorkoutExerciseItem.self, RepeatItem.self, GoalItem.self, ScheduledWorkoutItem.self], inMemory: true)
}
