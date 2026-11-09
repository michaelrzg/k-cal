//
//  LiftProgram.swift
//  k-cal
//
//  Turns goals and a schedule into a 13-week program: an original block periodization for size, with three blocks
//  that get heavier, rep tests in weeks 4 and 8 to update your numbers, and a max test in week 13. Pure logic, with
//  no storage or UI, so it can be tested.
//

import Foundation

enum LiftGoal: String, CaseIterable, Identifiable, Codable {
    case muscle = "Build Muscle"
    case strength = "Get Stronger"
    case lean = "Stay Lean"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .muscle: "Bodybuilding focus: more volume in the 8-15 rep range."
        case .strength: "Heavier compounds, lower reps, longer rests."
        case .lean: "Keep your muscle with fewer sets and shorter rests."
        }
    }

    var extraSets: Int {
        switch self {
        case .muscle: 1
        case .strength: 0
        case .lean: -1
        }
    }

    func restSeconds(for role: SlotRole) -> Int {
        let base = role == .main ? 150 : role == .secondary ? 120 : 75
        switch self {
        case .muscle: return base
        case .strength: return base + 45
        case .lean: return max(base - 30, 45)
        }
    }
}

enum LiftExperience: String, CaseIterable, Identifiable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .beginner: "Under a year of consistent lifting."
        case .intermediate: "One to three years, and you know the main lifts."
        case .advanced: "Three years or more of structured training."
        }
    }
}

enum SlotRole: String, Codable {
    /// The day's heavy barbell lift, driven by percentages.
    case main
    /// A second compound.
    case secondary
    /// Isolation work.
    case accessory
}

struct WorkoutSlot: Equatable {
    let exerciseID: String
    let role: SlotRole

    static func main(_ id: String) -> WorkoutSlot { WorkoutSlot(exerciseID: id, role: .main) }
    static func secondary(_ id: String) -> WorkoutSlot { WorkoutSlot(exerciseID: id, role: .secondary) }
    static func accessory(_ id: String) -> WorkoutSlot { WorkoutSlot(exerciseID: id, role: .accessory) }
}

struct SplitDay: Equatable {
    let name: String
    let focus: String
    /// Heavy days stay lower rep. Volume days go lighter for more reps.
    let isHeavy: Bool
    let slots: [WorkoutSlot]

    var muscles: [Muscle] {
        var seen = Set<Muscle>()
        return slots.compactMap { ExerciseCatalog.exercise($0.exerciseID)?.muscle }.filter { seen.insert($0).inserted }
    }
}

struct TrainingSplit: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let days: [SplitDay]

    var daysPerWeek: Int {
        days.count
    }
}

enum SplitLibrary {
    private static let pushHeavy = SplitDay(name: "Push", focus: "Chest, shoulders, triceps", isHeavy: true, slots: [
        .main("bench-press"), .secondary("incline-db-press"), .secondary("seated-db-press"), .accessory("cable-fly"),
        .accessory("lateral-raise"), .accessory("rope-pushdown"), .accessory("overhead-extension"),
    ])
    private static let pullHeavy = SplitDay(name: "Pull", focus: "Back, rear delts, biceps", isHeavy: true, slots: [
        .main("barbell-row"), .secondary("lat-pulldown"), .secondary("cable-row"), .accessory("face-pull"),
        .accessory("db-shrug"), .accessory("barbell-curl"), .accessory("hammer-curl"),
    ])
    private static let legsHeavy = SplitDay(name: "Legs", focus: "Quads, hamstrings, calves", isHeavy: true, slots: [
        .main("back-squat"), .secondary("romanian-deadlift"), .secondary("leg-press"), .accessory("leg-extension"),
        .accessory("lying-leg-curl"), .accessory("standing-calf-raise"), .accessory("cable-crunch"),
    ])
    private static let pushVolume = SplitDay(name: "Push Volume", focus: "Shoulders first, then chest", isHeavy: false, slots: [
        .main("overhead-press"), .secondary("incline-bench"), .secondary("machine-chest-press"), .accessory("pec-deck"),
        .accessory("cable-lateral-raise"), .accessory("skull-crusher"), .accessory("rope-pushdown"),
    ])
    private static let pullVolume = SplitDay(name: "Pull Volume", focus: "Width and thickness", isHeavy: false, slots: [
        .main("deadlift"), .secondary("pull-up"), .secondary("chest-supported-row"), .accessory("straight-arm-pulldown"),
        .accessory("reverse-fly"), .accessory("incline-curl"), .accessory("cable-curl"),
    ])
    private static let legsVolume = SplitDay(name: "Legs Volume", focus: "Quads and glutes", isHeavy: false, slots: [
        .main("front-squat"), .secondary("hip-thrust"), .secondary("bulgarian-split-squat"), .accessory("leg-extension"),
        .accessory("seated-leg-curl"), .accessory("seated-calf-raise"), .accessory("hanging-leg-raise"),
    ])

    static let fullBody = TrainingSplit(id: "full-body", name: "Full Body", detail: "Three whole-body days. The most gains per hour, and ideal when you're newer.", days: [
        SplitDay(name: "Full Body A", focus: "Squat and bench", isHeavy: true, slots: [
            .main("back-squat"), .main("bench-press"), .secondary("barbell-row"), .accessory("lateral-raise"), .accessory("barbell-curl"), .accessory("rope-pushdown"),
        ]),
        SplitDay(name: "Full Body B", focus: "Hinge and press", isHeavy: false, slots: [
            .main("deadlift"), .main("overhead-press"), .secondary("lat-pulldown"), .accessory("leg-extension"), .accessory("cable-fly"), .accessory("hammer-curl"),
        ]),
        SplitDay(name: "Full Body C", focus: "Volume all over", isHeavy: false, slots: [
            .secondary("leg-press"), .secondary("incline-db-press"), .secondary("cable-row"), .accessory("lying-leg-curl"), .accessory("face-pull"), .accessory("overhead-extension"), .accessory("standing-calf-raise"),
        ]),
    ])

    static let upperLower = TrainingSplit(id: "upper-lower", name: "Upper / Lower", detail: "Each muscle twice a week, a heavy day and a volume day. The best all-rounder.", days: [
        SplitDay(name: "Upper Heavy", focus: "Bench and row", isHeavy: true, slots: [
            .main("bench-press"), .main("barbell-row"), .secondary("seated-db-press"), .secondary("lat-pulldown"), .accessory("barbell-curl"), .accessory("rope-pushdown"),
        ]),
        SplitDay(name: "Lower Heavy", focus: "Squat focus", isHeavy: true, slots: [
            .main("back-squat"), .secondary("romanian-deadlift"), .secondary("leg-press"), .accessory("lying-leg-curl"), .accessory("standing-calf-raise"), .accessory("cable-crunch"),
        ]),
        SplitDay(name: "Upper Volume", focus: "Pump and isolation", isHeavy: false, slots: [
            .main("overhead-press"), .secondary("incline-db-press"), .secondary("cable-row"), .accessory("cable-fly"), .accessory("cable-lateral-raise"), .accessory("incline-curl"), .accessory("overhead-extension"),
        ]),
        SplitDay(name: "Lower Volume", focus: "Deadlift focus", isHeavy: false, slots: [
            .main("deadlift"), .secondary("hack-squat"), .secondary("bulgarian-split-squat"), .accessory("leg-extension"), .accessory("seated-leg-curl"), .accessory("seated-calf-raise"),
        ]),
    ])

    static let powerHypertrophy = TrainingSplit(id: "power-hypertrophy", name: "Power & Hypertrophy", detail: "Two strength days, then three bodybuilding days. Big lifts and big volume in five.", days: [
        SplitDay(name: "Upper Power", focus: "Heavy press and pull", isHeavy: true, slots: [
            .main("bench-press"), .main("barbell-row"), .secondary("overhead-press"), .secondary("pull-up"), .accessory("skull-crusher"), .accessory("barbell-curl"),
        ]),
        SplitDay(name: "Lower Power", focus: "Heavy squat and pull", isHeavy: true, slots: [
            .main("back-squat"), .main("deadlift"), .accessory("lying-leg-curl"), .accessory("standing-calf-raise"), .accessory("cable-crunch"),
        ]),
        SplitDay(name: "Back & Shoulders", focus: "Width, thickness, delts", isHeavy: false, slots: [
            .secondary("lat-pulldown"), .secondary("chest-supported-row"), .secondary("seated-db-press"), .accessory("straight-arm-pulldown"), .accessory("lateral-raise"), .accessory("face-pull"), .accessory("db-shrug"),
        ]),
        SplitDay(name: "Lower Pump", focus: "Quads, hamstrings, calves", isHeavy: false, slots: [
            .secondary("hack-squat"), .secondary("romanian-deadlift"), .secondary("bulgarian-split-squat"), .accessory("leg-extension"), .accessory("seated-leg-curl"), .accessory("seated-calf-raise"),
        ]),
        SplitDay(name: "Chest & Arms", focus: "Chest, biceps, triceps", isHeavy: false, slots: [
            .secondary("incline-db-press"), .secondary("machine-chest-press"), .accessory("cable-fly"), .accessory("incline-curl"), .accessory("rope-pushdown"), .accessory("cable-curl"), .accessory("overhead-extension"),
        ]),
    ])

    static let bodypart = TrainingSplit(id: "bodypart", name: "Body Part Split", detail: "One muscle group a day. The classic bodybuilder week, with maximum focus and pump.", days: [
        SplitDay(name: "Chest", focus: "Chest, all angles", isHeavy: true, slots: [
            .main("bench-press"), .secondary("incline-db-press"), .secondary("machine-chest-press"), .accessory("cable-fly"), .accessory("pec-deck"), .accessory("cable-crunch"),
        ]),
        SplitDay(name: "Back", focus: "Width and thickness", isHeavy: true, slots: [
            .main("deadlift"), .secondary("pull-up"), .secondary("barbell-row"), .secondary("cable-row"), .accessory("straight-arm-pulldown"), .accessory("db-shrug"),
        ]),
        SplitDay(name: "Shoulders", focus: "All three delt heads", isHeavy: false, slots: [
            .main("overhead-press"), .secondary("seated-db-press"), .accessory("lateral-raise"), .accessory("cable-lateral-raise"), .accessory("face-pull"), .accessory("reverse-fly"),
        ]),
        SplitDay(name: "Legs", focus: "Quads, hamstrings, calves", isHeavy: true, slots: [
            .main("back-squat"), .secondary("romanian-deadlift"), .secondary("leg-press"), .accessory("leg-extension"), .accessory("lying-leg-curl"), .accessory("standing-calf-raise"),
        ]),
        SplitDay(name: "Arms", focus: "Biceps and triceps", isHeavy: false, slots: [
            .secondary("close-grip-bench"), .secondary("barbell-curl"), .accessory("skull-crusher"), .accessory("incline-curl"), .accessory("rope-pushdown"), .accessory("hammer-curl"), .accessory("hanging-leg-raise"),
        ]),
    ])

    static let pushPullLegs = TrainingSplit(id: "ppl", name: "Push / Pull / Legs", detail: "Six days, each muscle twice a week with high volume. For when you're all in.", days: [
        pushHeavy, pullHeavy, legsHeavy, pushVolume, pullVolume, legsVolume,
    ])

    static let all = [fullBody, upperLower, powerHypertrophy, bodypart, pushPullLegs]

    static func split(id: String) -> TrainingSplit? {
        all.first { $0.id == id }
    }

    /// The split that suits the week best. Newer lifters get frequency over volume.
    static func recommended(daysPerWeek: Int, experience: LiftExperience, goal: LiftGoal) -> TrainingSplit {
        switch daysPerWeek {
        case ...3: return fullBody
        case 4: return upperLower
        case 5: return experience == .beginner ? upperLower : (goal == .muscle ? bodypart : powerHypertrophy)
        default: return experience == .beginner ? upperLower : pushPullLegs
        }
    }

    static func options(daysPerWeek: Int) -> [TrainingSplit] {
        all.filter { $0.daysPerWeek <= max(daysPerWeek, 3) }.sorted { $0.daysPerWeek > $1.daysPerWeek }
    }
}

/// What one kind of lift does in a given week.
struct Prescription: Equatable {
    var sets: Int
    var reps: Int
    /// Share of one-rep max. Nil means work from the reps: leave `repsInReserve` in the tank.
    var percent: Double?
    var repsInReserve: Int
    /// The last set goes to a hard rep max, to update the lift's numbers.
    var isRepTest = false
}

struct ProgramWeek: Equatable, Identifiable {
    enum Kind {
        case training
        case repTest
        case deload
        case maxTest
    }

    let number: Int
    let phase: String
    let note: String
    let kind: Kind
    let main: Prescription
    let secondary: Prescription
    let accessory: Prescription

    var id: Int { number }
}

enum ProgramCalendar {
    static let weekCount = 13

    static let weeks: [ProgramWeek] = [
        week(1, "Foundation", "Groove your form. Stop with two reps left.", main: (4, 10, 0.675), secondary: (3, 12, 2), accessory: (3, 15, 2)),
        week(2, "Foundation", "Same work, a little more weight.", main: (4, 10, 0.70), secondary: (3, 12, 2), accessory: (3, 15, 1)),
        week(3, "Foundation", "The hardest week of the block.", main: (4, 9, 0.725), secondary: (4, 10, 1), accessory: (4, 12, 1)),
        week(4, "Rep Test", "Light accessories, then a rep test to update your numbers.", main: (3, 5, 0.825), secondary: (2, 10, 3), accessory: (2, 12, 3), kind: .repTest),
        week(5, "Build", "New numbers. Heavier, with reps in the 6-8 range.", main: (4, 8, 0.725), secondary: (4, 10, 2), accessory: (3, 12, 2)),
        week(6, "Build", "Push your accessories close to failure.", main: (4, 7, 0.775), secondary: (4, 8, 1), accessory: (4, 10, 1)),
        week(7, "Build", "Peak of the volume. Eat plenty and sleep well.", main: (5, 6, 0.80), secondary: (4, 8, 1), accessory: (4, 10, 0)),
        week(8, "Rep Test", "A lighter week ending in another rep test.", main: (3, 4, 0.875), secondary: (2, 8, 3), accessory: (2, 10, 3), kind: .repTest),
        week(9, "Intensify", "Heavy triples and fives. Rest fully between sets.", main: (5, 5, 0.825), secondary: (3, 8, 1), accessory: (3, 10, 1)),
        week(10, "Intensify", "Move the weight with intent.", main: (5, 4, 0.85), secondary: (3, 6, 1), accessory: (3, 10, 1)),
        week(11, "Intensify", "The heaviest work of the program.", main: (4, 3, 0.90), secondary: (3, 6, 1), accessory: (3, 8, 0)),
        week(12, "Deload", "Let fatigue fall away before testing.", main: (3, 3, 0.675), secondary: (2, 8, 4), accessory: (2, 10, 4), kind: .deload),
        week(13, "Max Test", "Work up to a heavy single or double. New personal records.", main: (3, 2, 0.925), secondary: (2, 6, 4), accessory: (1, 10, 4), kind: .maxTest),
    ]

    private static func week(_ number: Int, _ phase: String, _ note: String, main: (Int, Int, Double), secondary: (Int, Int, Int), accessory: (Int, Int, Int), kind: ProgramWeek.Kind = .training) -> ProgramWeek {
        ProgramWeek(
            number: number, phase: phase, note: note, kind: kind,
            main: Prescription(sets: main.0, reps: main.1, percent: main.2, repsInReserve: 1, isRepTest: kind == .repTest || kind == .maxTest),
            secondary: Prescription(sets: secondary.0, reps: secondary.1, percent: nil, repsInReserve: secondary.2),
            accessory: Prescription(sets: accessory.0, reps: accessory.1, percent: nil, repsInReserve: accessory.2)
        )
    }

    static func week(_ number: Int) -> ProgramWeek {
        weeks[min(max(number, 1), weekCount) - 1]
    }
}

/// One exercise in one session, with its target worked out.
struct PlannedExercise: Identifiable, Equatable {
    /// Identifies the place in the split, so a swap applies every week.
    let slotKey: String
    let exercise: Exercise
    let role: SlotRole
    let sets: Int
    let reps: Int
    let targetWeight: Double?
    let repsInReserve: Int
    let isRepTest: Bool
    let restSeconds: Int

    var id: String { slotKey }
}

struct PlannedWorkout: Identifiable, Equatable {
    let week: ProgramWeek
    let dayIndex: Int
    let day: SplitDay
    let exercises: [PlannedExercise]

    var id: String { "\(week.number)-\(dayIndex)" }

    var estimatedMinutes: Int {
        let seconds = exercises.reduce(0) { $0 + $1.sets * ($1.restSeconds + 40) }
        return Int((Double(seconds) / 60 / 5).rounded()) * 5
    }
}

/// One-rep maxes: your own where known, otherwise estimated from bodyweight.
struct StrengthProfile: Equatable {
    var bodyweight: Double
    var experience: LiftExperience
    /// Known one-rep maxes by exercise ID.
    var maxes: [String: Double] = [:]
    /// Pounds, or kilograms if false.
    var usesPounds = true

    /// Epley runs a touch light for isolation work taken close to failure.
    private static let accessoryLoadBump = 1.025

    /// Epley: a set of `reps` at `weight` predicts this one-rep max.
    static func estimatedMax(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return 0 }
        return reps == 1 ? weight : weight * (1 + Double(reps) / 30)
    }

    /// The share of one-rep max you can lift for this many reps.
    static func shareOfMax(reps: Int) -> Double {
        1 / (1 + Double(reps) / 30)
    }

    func anchorMax(_ anchor: AnchorLift) -> Double {
        maxes[anchor.exerciseID] ?? bodyweight * anchor.bodyweightRatio(for: experience)
    }

    /// Your own number, or one scaled from the lift this exercise is based on.
    func oneRepMax(for exercise: Exercise) -> Double? {
        if let known = maxes[exercise.id] { return known }
        guard let anchor = exercise.anchor else { return nil }
        return anchorMax(anchor) * exercise.ratio
    }

    /// Rounds to a load you can actually set up.
    func rounded(_ weight: Double, for exercise: Exercise) -> Double {
        let step = usesPounds ? exercise.equipment.increment : exercise.equipment.increment / 2
        guard step > 0 else { return weight }
        return max((weight / step).rounded() * step, step)
    }

    func targetWeight(for exercise: Exercise, prescription: Prescription) -> Double? {
        guard let max = oneRepMax(for: exercise) else { return nil }
        let share = prescription.percent ?? Self.shareOfMax(reps: prescription.reps + prescription.repsInReserve) * Self.accessoryLoadBump
        return rounded(max * share, for: exercise)
    }
}

enum WorkoutPlanner {
    static func slotKey(split: TrainingSplit, dayIndex: Int, slotIndex: Int) -> String {
        "\(split.id).\(dayIndex).\(slotIndex)"
    }

    static func workout(split: TrainingSplit, week: ProgramWeek, dayIndex: Int, profile: StrengthProfile, goal: LiftGoal, swaps: [String: String] = [:], focus: Muscle? = nil) -> PlannedWorkout {
        let day = split.days[dayIndex]
        let isLoaded = week.kind == .training
        let exercises = day.slots.enumerated().compactMap { index, slot -> PlannedExercise? in
            let key = slotKey(split: split, dayIndex: dayIndex, slotIndex: index)
            guard let exercise = ExerciseCatalog.exercise(swaps[key] ?? slot.exerciseID) else { return nil }
            var plan: Prescription = switch slot.role {
            case .main: week.main
            case .secondary: week.secondary
            case .accessory: week.accessory
            }
            if isLoaded {
                if slot.role != .main { plan.sets = max(plan.sets + goal.extraSets, 2) }
                if slot.role == .main, goal == .strength { plan.reps = max(plan.reps - 2, 3) }
                if !day.isHeavy, slot.role == .main, let percent = plan.percent {
                    // Volume days stay lighter for more reps, so one lift isn't always heavy.
                    plan.percent = percent - 0.05
                    plan.reps += 2
                }
                if exercise.muscle == focus { plan.sets += 1 }
            }
            return PlannedExercise(
                slotKey: key, exercise: exercise, role: slot.role, sets: plan.sets, reps: plan.reps,
                targetWeight: profile.targetWeight(for: exercise, prescription: plan), repsInReserve: plan.repsInReserve,
                isRepTest: plan.isRepTest, restSeconds: goal.restSeconds(for: slot.role)
            )
        }
        return PlannedWorkout(week: week, dayIndex: dayIndex, day: day, exercises: exercises)
    }

    /// The next session in order: missing a day never skips work, it just moves everything back.
    static func nextSession(split: TrainingSplit, completed: Set<String>) -> (week: Int, dayIndex: Int)? {
        for week in 1 ... ProgramCalendar.weekCount {
            for day in split.days.indices where !completed.contains("\(week)-\(day)") {
                return (week, day)
            }
        }
        return nil
    }

    /// Spreads training days through the week, Monday first, with gaps where they do the most good.
    static func suggestedWeekdays(daysPerWeek: Int) -> [Int] {
        switch daysPerWeek {
        case ...2: [2, 5]
        case 3: [2, 4, 6]
        case 4: [2, 3, 5, 6]
        case 5: [2, 3, 4, 6, 7]
        default: [2, 3, 4, 5, 6, 7]
        }
    }
}

/// A single session built on the spot, outside the program.
enum QuickWorkoutBuilder {
    static func workout(muscles: [Muscle], minutes: Int, profile: StrengthProfile, goal: LiftGoal, equipment: Set<Equipment> = Set(Equipment.allCases)) -> [PlannedExercise] {
        let perMinute = 8.0
        let total = max(Int(Double(minutes) / perMinute), 3)
        guard !muscles.isEmpty else { return [] }
        let share = max(total / muscles.count, 1)
        var picked: [PlannedExercise] = []
        for muscle in muscles {
            var seenFamilies = Set<ExerciseFamily>()
            // Compounds first: they have the higher ratio to their anchor lift.
            let options = ExerciseCatalog.all
                .filter { $0.muscle == muscle && equipment.contains($0.equipment) }
                .sorted { $0.ratio > $1.ratio }
                .filter { seenFamilies.insert($0.family).inserted }
            for (index, exercise) in options.prefix(share).enumerated() {
                let role: SlotRole = index == 0 ? .secondary : .accessory
                let plan = Prescription(sets: 3, reps: index == 0 ? 10 : 12, percent: nil, repsInReserve: 2)
                picked.append(PlannedExercise(
                    slotKey: "quick.\(exercise.id)", exercise: exercise, role: role, sets: plan.sets, reps: plan.reps,
                    targetWeight: profile.targetWeight(for: exercise, prescription: plan), repsInReserve: plan.repsInReserve,
                    isRepTest: false, restSeconds: goal.restSeconds(for: role)
                ))
            }
        }
        return Array(picked.prefix(total))
    }
}
