import Foundation

enum ScheduleCalendar {
    static func currentWeekID(date: Date = Date()) -> String {
        var calendar = Calendar.current
        calendar.firstWeekday = Weekday.sunday.rawValue

        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromSunday = weekday - Weekday.sunday.rawValue
        let sunday = calendar.date(byAdding: .day, value: -daysFromSunday, to: startOfDay) ?? startOfDay

        return sunday.formatted(.iso8601.year().month().day())
    }
}
