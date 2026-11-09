//
//  WidgetSync.swift
//  k-cal
//
//  Keeps the summary that widgets read in step with the food log.
//

import Foundation
import WidgetKit

enum WidgetSync {
    static func snapshot(foods: [Food], user: User?, plan: LiftPlan? = nil, at date: Date, calendar: Calendar = .current) -> DailySnapshot {
        let day = calendar.startOfDay(for: date)
        var snapshot = DailySnapshot(day: day)
        if user != nil || plan != nil {
            let goals = DayGoals.resolved(user: user, plan: plan, on: date, calendar: calendar)
            snapshot.calorieGoal = goals.calories
            snapshot.proteinGoal = goals.protein
            snapshot.carbohydrateGoal = goals.carbohydrates
            snapshot.fatGoal = goals.fat
        }
        if let plan, plan.matchesNutrition {
            let nutrition = plan.nutrition
            snapshot.scheduledGoals = ScheduledGoals(training: nutrition.training, rest: nutrition.rest, weekdays: plan.weekdays)
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

    /// The next session, for the widgets. Nil with no plan, or once the program's finished.
    static func liftSnapshot(plan: LiftPlan?, maxes: [LiftMax], swaps: [LiftSwap], logs: [WorkoutLog]) -> LiftSnapshot? {
        guard let plan else { return nil }
        let split = plan.split
        guard let next = WorkoutPlanner.nextSession(split: split, completed: plan.completedSessions(in: logs)) else { return nil }
        let workout = WorkoutPlanner.workout(
            split: split, week: ProgramCalendar.week(next.week), dayIndex: next.dayIndex, profile: plan.profile(maxes: maxes), goal: plan.goal,
            swaps: Dictionary(swaps.map { ($0.slotKey, $0.exerciseID) }, uniquingKeysWith: { _, new in new }), focus: plan.focus
        )
        return LiftSnapshot(
            week: workout.week.number, totalWeeks: ProgramCalendar.weekCount, phase: workout.week.phase, dayName: workout.day.name,
            focus: workout.day.focus, minutes: workout.estimatedMinutes,
            lines: workout.exercises.prefix(3).map { .init(name: $0.exercise.name, detail: LiftFormat.prescription($0, unit: plan.unit)) },
            weekdays: plan.weekdays, lastTrained: logs.map(\.date).max()
        )
    }

    static func publish(_ snapshot: LiftSnapshot?) {
        guard snapshot != LiftSnapshot.load() else { return }
        LiftSnapshot.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Widget reloads are budgeted by the system, so nothing is sent unless the numbers changed.
    static func publish(_ snapshot: DailySnapshot) {
        guard snapshot != DailySnapshot.load(for: snapshot.day) else { return }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
