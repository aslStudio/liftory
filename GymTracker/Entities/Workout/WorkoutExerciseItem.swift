import Foundation
import SwiftData

@Model
final class WorkoutExerciseItem {
    var id: UUID = UUID()
    var exerciseID: UUID?
    @Relationship(deleteRule: .nullify)
    var exercise: ExerciseItem?
    var sortOrder: Int = 0

    init(
        id: UUID = UUID(),
        exerciseID: UUID? = nil,
        exercise: ExerciseItem?,
        sortOrder: Int
    ) {
        self.id = id
        self.exerciseID = exerciseID ?? exercise?.id
        self.exercise = exercise
        self.sortOrder = sortOrder
    }
}
