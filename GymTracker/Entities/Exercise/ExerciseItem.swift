import Foundation
import SwiftData

@Model
final class ExerciseItem {
    var id: UUID = UUID()
    var name: String = ""
    var type: RepeatType = RepeatType.repeats
    @Relationship(deleteRule: .cascade)
    var repeats: [RepeatItem] = []
    var isFavorite: Bool = false
    
    init(
        id: UUID = UUID(),
        name: String,
        type: RepeatType,
        repeats: [RepeatItem],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.repeats = repeats
        self.isFavorite = isFavorite
    }
}
