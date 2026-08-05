import Foundation
import SwiftData

@Model
final class GoalItem {
    var id: UUID = UUID()
    var title: String = ""
    var exerciseID: UUID?
    @Relationship(deleteRule: .nullify)
    var exercise: ExerciseItem?
    var metric: GoalMetric = GoalMetric.maxWeight
    var targetValue: Double = 0
    var createdAt: String = ""
    var isCompleted: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        exerciseID: UUID? = nil,
        exercise: ExerciseItem?,
        metric: GoalMetric,
        targetValue: Double,
        createdAt: String,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.exerciseID = exerciseID ?? exercise?.id
        self.exercise = exercise
        self.metric = metric
        self.targetValue = targetValue
        self.createdAt = createdAt
        self.isCompleted = isCompleted
    }
}

enum GoalMetric: String, Codable, CaseIterable, Identifiable {
    case maxWeight
    case totalSets
    case totalVolume

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maxWeight:
            "Max Weight"
        case .totalSets:
            "Total Sets"
        case .totalVolume:
            "Total Volume"
        }
    }
}
