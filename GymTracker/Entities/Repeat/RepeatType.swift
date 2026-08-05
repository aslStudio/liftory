enum RepeatType: String, Codable, CaseIterable, Identifiable {
    case distance
    case time
    case repeats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .distance:
            "Distance"
        case .time:
            "Time"
        case .repeats:
            "Repeats"
        }
    }
}
