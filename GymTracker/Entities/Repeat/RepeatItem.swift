import Foundation
import SwiftData

@Model
final class RepeatItem {
    var id: UUID = UUID()
    var type: RepeatType = RepeatType.repeats
    var value: Double = 0
    var weight: Double?
    var createdAt: String = ""
    
    init(
        id: UUID = UUID(),
        type: RepeatType,
        value: Double,
        weight: Double? = nil,
        createdAt: String
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.weight = weight
        self.createdAt = createdAt
    }
}
