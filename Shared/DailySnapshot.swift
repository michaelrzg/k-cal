//
//  DailySnapshot.swift
//  k-cal
//
//  Today's totals, shared between the app and its widgets. Widgets run in their own process and can't open
//  the app's SwiftData store, so the app writes this small summary to the App Group whenever it changes.
//

import Foundation

struct DailySnapshot: Codable, Equatable {
    static let appGroup = "group.rizig.k-cal"
    private static let key = "dailySnapshot"

    /// The start of the day these totals belong to.
    var day: Date
    var calories = 0
    var protein = 0
    var carbohydrates = 0
    var fat = 0
    var calorieGoal = 2000
    var proteinGoal = 150
    var carbohydrateGoal = 200
    var fatGoal = 65

    var caloriesLeft: Int {
        calorieGoal - calories
    }

    var calorieProgress: Double {
        Self.progress(calories, of: calorieGoal)
    }

    /// Between 0 and 1, so an empty goal or a day over target can't break a bar.
    static func progress(_ value: Int, of goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(Double(value) / Double(goal), 0), 1)
    }

    /// The same goals with nothing eaten, for when the saved totals are from an earlier day.
    func cleared(for day: Date) -> DailySnapshot {
        var fresh = self
        fresh.day = day
        fresh.calories = 0
        fresh.protein = 0
        fresh.carbohydrates = 0
        fresh.fat = 0
        return fresh
    }

    /// What to show at `date`. Totals from another day never carry over.
    static func load(for date: Date, calendar: Calendar = .current, defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) -> DailySnapshot {
        let day = calendar.startOfDay(for: date)
        guard let data = defaults?.data(forKey: key),
              let saved = try? JSONDecoder().decode(DailySnapshot.self, from: data)
        else { return DailySnapshot(day: day) }
        return calendar.isDate(saved.day, inSameDayAs: day) ? saved : saved.cleared(for: day)
    }

    func save(defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) {
        defaults?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
