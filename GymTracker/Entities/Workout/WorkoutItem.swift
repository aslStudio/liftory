import Foundation
import SwiftData

@Model
final class WorkoutItem {
    var id: UUID = UUID()
    var name: String = ""
    var durations: [Int] = []
    @Relationship(deleteRule: .cascade)
    var exerciseItems: [WorkoutExerciseItem] = []

    var orderedExercises: [ExerciseItem] {
        exerciseItems
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap(\.exercise)
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        durations: [Int],
        exerciseItems: [WorkoutExerciseItem]
    ) {
        self.id = id
        self.name = name
        self.durations = durations
        self.exerciseItems = exerciseItems
    }
}
