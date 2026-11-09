//
//  LiftModels.swift
//  k-cal
//
//  What's saved about training: the plan, your numbers, swaps, and every workout logged.
//

import Foundation
import SwiftData

@Model
class LiftPlan {
    var goalRaw: String
    var experienceRaw: String
    var splitID: String
    /// Training days, as Calendar weekdays (Sunday is 1).
    var weekdays: [Int]
    var bodyweight: Double
    var usesPounds: Bool
    var focusRaw: String?
    var started: Date
    /// Just show the sets, with no checkboxes or rest timer.
    var isSelfPaced: Bool = false
    /// Base daily food goals on training, rather than the goals in Profile.
    var matchesNutrition: Bool = false

    init(goal: LiftGoal, experience: LiftExperience, splitID: String, weekdays: [Int], bodyweight: Double, usesPounds: Bool, focus: Muscle?, started: Date = Date(), isSelfPaced: Bool = false, matchesNutrition: Bool = false) {
        goalRaw = goal.rawValue
        experienceRaw = experience.rawValue
        self.splitID = splitID
        self.weekdays = weekdays
        self.bodyweight = bodyweight
        self.usesPounds = usesPounds
        focusRaw = focus?.rawValue
        self.started = started
        self.isSelfPaced = isSelfPaced
        self.matchesNutrition = matchesNutrition
    }

    var goal: LiftGoal { LiftGoal(rawValue: goalRaw) ?? .muscle }
    var experience: LiftExperience { LiftExperience(rawValue: experienceRaw) ?? .intermediate }
    var focus: Muscle? { focusRaw.flatMap(Muscle.init(rawValue:)) }
    var split: TrainingSplit { SplitLibrary.split(id: splitID) ?? SplitLibrary.upperLower }
    var unit: String { usesPounds ? "lb" : "kg" }

    var nutrition: NutritionPlan {
        NutritionPlan(bodyweight: bodyweight, usesPounds: usesPounds, goal: goal, trainingDays: weekdays.count)
    }

    /// Sessions done in this run of the program. Workouts from an earlier one don't count.
    func completedSessions(in logs: [WorkoutLog]) -> Set<String> {
        Set(logs.filter { $0.date >= started }.compactMap(\.sessionKey))
    }
}

@Model
class LiftMax {
    @Attribute(.unique) var exerciseID: String
    var oneRepMax: Double
    var updated: Date

    init(exerciseID: String, oneRepMax: Double) {
        self.exerciseID = exerciseID
        self.oneRepMax = oneRepMax
        updated = Date()
    }
}

/// An exercise swapped into a place in the split.
@Model
class LiftSwap {
    @Attribute(.unique) var slotKey: String
    var exerciseID: String

    init(slotKey: String, exerciseID: String) {
        self.slotKey = slotKey
        self.exerciseID = exerciseID
    }
}

@Model
class WorkoutLog {
    var date: Date
    var title: String
    /// The program position, or nil for a quick workout.
    var week: Int?
    var dayIndex: Int?
    var minutes: Int
    @Relationship(deleteRule: .cascade, inverse: \SetLog.workout) var sets: [SetLog] = []

    init(date: Date, title: String, week: Int?, dayIndex: Int?, minutes: Int) {
        self.date = date
        self.title = title
        self.week = week
        self.dayIndex = dayIndex
        self.minutes = minutes
    }

    var sessionKey: String? {
        guard let week, let dayIndex else { return nil }
        return "\(week)-\(dayIndex)"
    }
}

@Model
class SetLog {
    var exerciseID: String
    var setNumber: Int
    var weight: Double
    var reps: Int
    var workout: WorkoutLog?

    init(exerciseID: String, setNumber: Int, weight: Double, reps: Int) {
        self.exerciseID = exerciseID
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
    }

    var estimatedMax: Double {
        StrengthProfile.estimatedMax(weight: weight, reps: reps)
    }
}

extension LiftPlan {
    func profile(maxes: [LiftMax]) -> StrengthProfile {
        StrengthProfile(
            bodyweight: bodyweight, experience: experience,
            maxes: Dictionary(maxes.map { ($0.exerciseID, $0.oneRepMax) }, uniquingKeysWith: max),
            usesPounds: usesPounds
        )
    }
}

enum LiftFormat {
    static func weight(_ value: Double, unit: String) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0 ... 1)))) \(unit)"
    }

    static func prescription(_ exercise: PlannedExercise, unit: String) -> String {
        let reps = exercise.isRepTest ? "\(exercise.sets) x \(exercise.reps)+" : "\(exercise.sets) x \(exercise.reps)"
        guard let weight = exercise.targetWeight else { return "\(reps), bodyweight" }
        return "\(reps) at \(self.weight(weight, unit: unit))"
    }

    static func reserve(_ reps: Int) -> String {
        reps == 0 ? "Take the last set close to failure" : "Stop with about \(reps) \(reps == 1 ? "rep" : "reps") left"
    }
}
