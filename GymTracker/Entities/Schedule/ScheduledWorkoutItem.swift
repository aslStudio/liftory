import Foundation
import SwiftData

@Model
final class ScheduledWorkoutItem {
    var id: UUID = UUID()
    var day: Weekday = Weekday.monday
    var workoutID: UUID?
    @Relationship(deleteRule: .nullify)
    var workout: WorkoutItem?
    var completedWeekID: String?
    var createdAt: String = ""

    init(
        id: UUID = UUID(),
        day: Weekday,
        workoutID: UUID? = nil,
        workout: WorkoutItem?,
        completedWeekID: String? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.day = day
        self.workoutID = workoutID ?? workout?.id
        self.workout = workout
        self.completedWeekID = completedWeekID
        self.createdAt = createdAt
    }
}

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sunday:
            "Sunday"
        case .monday:
            "Monday"
        case .tuesday:
            "Tuesday"
        case .wednesday:
            "Wednesday"
        case .thursday:
            "Thursday"
        case .friday:
            "Friday"
        case .saturday:
            "Saturday"
        }
    }

    var shortTitle: String {
        switch self {
        case .sunday:
            "Sun"
        case .monday:
            "Mon"
        case .tuesday:
            "Tue"
        case .wednesday:
            "Wed"
        case .thursday:
            "Thu"
        case .friday:
            "Fri"
        case .saturday:
            "Sat"
        }
    }

    static var weekOrder: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    static var today: Weekday {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return Weekday(rawValue: weekday) ?? .monday
    }
}
