//
//  NutritionPlan.swift
//  k-cal
//
//  Daily food goals that follow your training: a bit more food on lifting days, less on rest days, and enough
//  protein for your bodyweight. These are estimates from bodyweight and activity alone, without height or age.
//

import Foundation

struct NutritionPlan: Equatable {
    /// Calories burned a day per pound of bodyweight, before training is added.
    private static let baseCaloriesPerPound = 13.0
    private static let caloriesPerTrainingDay = 0.5
    /// How far a lifting day sits from a rest day, either side of the weekly average.
    private static let trainingDayShift = 300.0
    private static let fatPerPound = 0.35
    private static let poundsPerKilogram = 2.20462

    let training: DayGoals
    let rest: DayGoals
    /// The average a day across the week, before goal adjustments are split between day types.
    let dailyAverage: Int

    init(bodyweight: Double, usesPounds: Bool, goal: LiftGoal, trainingDays: Int) {
        let pounds = usesPounds ? bodyweight : bodyweight * Self.poundsPerKilogram
        let days = Double(min(max(trainingDays, 0), 7))
        let maintenance = pounds * (Self.baseCaloriesPerPound + Self.caloriesPerTrainingDay * days)
        let factor: Double = switch goal {
        case .muscle: 1.10
        case .strength: 1.05
        case .lean: 0.85
        }
        let average = maintenance * factor
        // Shifted so the week still averages out to the same total.
        let trainingCalories = average + Self.trainingDayShift * (7 - days) / 7
        let restCalories = average - Self.trainingDayShift * days / 7
        let protein = Int((pounds * (goal == .lean ? 1.1 : 1.0)).rounded())
        let fat = Int((pounds * Self.fatPerPound).rounded())

        func goals(_ calories: Double) -> DayGoals {
            let rounded = Int((calories / 10).rounded()) * 10
            return DayGoals(calories: rounded, protein: protein, carbohydrates: max((rounded - protein * 4 - fat * 9) / 4, 0), fat: fat)
        }
        training = goals(trainingCalories)
        rest = goals(restCalories)
        dailyAverage = Int((average / 10).rounded()) * 10
    }
}

extension DayGoals {
    init(user: User?) {
        self.init(calories: user?.calorie_goal ?? 2000, protein: user?.protein_goal ?? 150, carbohydrates: user?.carb_goal ?? 200, fat: user?.fat_goal ?? 65)
    }

    /// The goals for a date: your Lifts plan's if you've turned that on, otherwise the ones in Profile.
    static func resolved(user: User?, plan: LiftPlan?, on date: Date, calendar: Calendar = .current) -> DayGoals {
        guard let plan, plan.matchesNutrition else { return DayGoals(user: user) }
        let nutrition = plan.nutrition
        return plan.weekdays.contains(calendar.component(.weekday, from: date)) ? nutrition.training : nutrition.rest
    }
}

extension LiftPlan {
    /// A note for the summary card, when these goals are driving the day's numbers.
    func goalCaption(on date: Date, calendar: Calendar = .current) -> String? {
        guard matchesNutrition else { return nil }
        return weekdays.contains(calendar.component(.weekday, from: date)) ? "Training day goals" : "Rest day goals"
    }
}
