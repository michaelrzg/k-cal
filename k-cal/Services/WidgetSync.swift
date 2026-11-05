//
//  WidgetSync.swift
//  k-cal
//
//  Keeps the summary that widgets read in step with the food log.
//

import Foundation
import WidgetKit

enum WidgetSync {
    static func snapshot(foods: [Food], user: User?, at date: Date, calendar: Calendar = .current) -> DailySnapshot {
        let day = calendar.startOfDay(for: date)
        var snapshot = DailySnapshot(day: day)
        if let user {
            snapshot.calorieGoal = user.calorie_goal
            snapshot.proteinGoal = user.protein_goal
            snapshot.carbohydrateGoal = user.carb_goal
            snapshot.fatGoal = user.fat_goal
        }
        for food in foods {
            guard let logged = food.day?.date, calendar.isDate(logged, inSameDayAs: day) else { continue }
            snapshot.calories += food.calories
            snapshot.protein += food.protein
            snapshot.carbohydrates += food.carbohydrates
            snapshot.fat += food.fat
        }
        return snapshot
    }

    /// Widget reloads are budgeted by the system, so nothing is sent unless the numbers changed.
    static func publish(_ snapshot: DailySnapshot) {
        guard snapshot != DailySnapshot.load(for: snapshot.day) else { return }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
