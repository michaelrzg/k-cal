//
//  LiftSnapshot.swift
//  k-cal
//
//  The next workout, shared with the widgets the same way as today's food totals.
//

import Foundation

struct LiftSnapshot: Codable, Equatable {
    struct Line: Codable, Equatable {
        let name: String
        let detail: String
    }

    private static let key = "liftSnapshot"

    var week: Int
    var totalWeeks: Int
    var phase: String
    var dayName: String
    var focus: String
    var minutes: Int
    var lines: [Line]
    /// Training days, as Calendar weekdays.
    var weekdays: [Int]
    var lastTrained: Date?

    enum Status: Equatable {
        case today
        case done
        case rest
    }

    func status(on date: Date, calendar: Calendar = .current) -> Status {
        if let lastTrained, calendar.isDate(lastTrained, inSameDayAs: date) { return .done }
        return weekdays.contains(calendar.component(.weekday, from: date)) ? .today : .rest
    }

    func headline(on date: Date) -> String {
        switch status(on: date) {
        case .today: "Today"
        case .done: "Done today. Up next"
        case .rest: "Rest day. Up next"
        }
    }

    var progress: Double {
        Double(week) / Double(max(totalWeeks, 1))
    }

    static func load(defaults: UserDefaults? = UserDefaults(suiteName: DailySnapshot.appGroup)) -> LiftSnapshot? {
        defaults?.data(forKey: key).flatMap { try? JSONDecoder().decode(LiftSnapshot.self, from: $0) }
    }

    static func save(_ snapshot: LiftSnapshot?, defaults: UserDefaults? = UserDefaults(suiteName: DailySnapshot.appGroup)) {
        defaults?.set(snapshot.flatMap { try? JSONEncoder().encode($0) }, forKey: key)
    }
}
