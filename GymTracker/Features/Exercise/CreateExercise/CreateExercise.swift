import SwiftUI
import SwiftData

struct CreateExercise: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var type: RepeatType = .repeats

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)

                Picker("Repeat type", selection: $type) {
                    ForEach(RepeatType.allCases) { type in
                        Text(type.title)
                            .tag(type)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            AppGlassBackground()
        }
        .navigationTitle("Create Exercise")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveExercise()
                }
                .disabled(trimmedName.isEmpty)
            }
        }
    }

    private func saveExercise() {
        let exercise = ExerciseItem(
            name: trimmedName,
            type: type,
            repeats: []
        )

        modelContext.insert(exercise)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save exercise: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        CreateExercise()
    }
    .modelContainer(for: [ExerciseItem.self, WorkoutItem.self, WorkoutExerciseItem.self, RepeatItem.self, GoalItem.self, ScheduledWorkoutItem.self], inMemory: true)
}
