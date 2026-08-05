import SwiftUI
import SwiftData

struct WorkoutExerciseSelection: Identifiable {
    let id: UUID
    let exerciseID: UUID

    init(id: UUID = UUID(), exerciseID: UUID) {
        self.id = id
        self.exerciseID = exerciseID
    }
}

struct WorkoutForm: View {
    @Query(sort: \ExerciseItem.name) private var exercises: [ExerciseItem]

    @Binding var name: String
    @Binding var selectedExercises: [WorkoutExerciseSelection]

    private var selectedExerciseItems: [ExerciseItem] {
        selectedExercises.compactMap { selection in
            exercise(for: selection)
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
            }
            
            Section("Selected Exercises") {
                if selectedExerciseItems.isEmpty {
                    ContentUnavailableView(
                        "No Selected Exercises",
                        systemImage: "list.number",
                        description: Text("Added exercises will appear here in workout order.")
                    )
                } else {
                    ForEach(selectedExercises) { selection in
                        if let exercise = exercise(for: selection) {
                            HStack {
                                Text(exercise.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeSelection(selection)
                                } label: {
                                    Label("Remove", systemImage: "minus.circle")
                                }
                            }
                        }
                    }
                    .onMove(perform: moveExercises)
                    .onDelete(perform: deleteExercises)
                }
            }

            Section("All Exercises") {
                if exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Create exercises before adding them to a workout.")
                    )
                } else {
                    ForEach(exercises) { exercise in
                        Button {
                            addExercise(exercise)
                        } label: {
                            HStack {
                                Text(exercise.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            AppGlassBackground()
        }
    }

    func selectedWorkoutExercises() -> [ExerciseItem] {
        selectedExerciseItems
    }

    private func exercise(for selection: WorkoutExerciseSelection) -> ExerciseItem? {
        exercises.first { $0.id == selection.exerciseID }
    }

    private func addExercise(_ exercise: ExerciseItem) {
        selectedExercises.append(
            WorkoutExerciseSelection(exerciseID: exercise.id)
        )
    }

    private func removeSelection(_ selection: WorkoutExerciseSelection) {
        selectedExercises.removeAll { $0.id == selection.id }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        selectedExercises.move(fromOffsets: source, toOffset: destination)
    }

    private func deleteExercises(at offsets: IndexSet) {
        selectedExercises.remove(atOffsets: offsets)
    }
}
