//
//  LiftProgramTests.swift
//  k-calTests
//

import Foundation
import SwiftData
import Testing
@testable import k_cal

struct ExerciseCatalogTests {
    @Test func everySplitUsesRealExercises() {
        for split in SplitLibrary.all {
            for day in split.days {
                #expect(!day.slots.isEmpty)
                for slot in day.slots {
                    #expect(ExerciseCatalog.exercise(slot.exerciseID) != nil, "\(split.name): \(slot.exerciseID)")
                }
            }
        }
    }

    @Test func everyBodyPartHasSeveralExercises() {
        for muscle in Muscle.allCases {
            #expect(ExerciseCatalog.all.filter { $0.muscle == muscle }.count >= 2, "\(muscle)")
        }
    }

    @Test func mostExercisesHaveAlternatives() {
        let lonely = ExerciseCatalog.all.filter { ExerciseCatalog.alternatives(to: $0).isEmpty }
        #expect(lonely.isEmpty, "\(lonely.map(\.name))")
    }

    @Test func idsAreUniqueAndCuesAreWritten() {
        #expect(Set(ExerciseCatalog.all.map(\.id)).count == ExerciseCatalog.all.count)
        #expect(ExerciseCatalog.all.allSatisfy { $0.cues.count == 3 })
    }

    @Test func loadedExercisesScaleFromALift() {
        #expect(ExerciseCatalog.all.filter { !$0.isBodyweight }.allSatisfy { $0.anchor != nil && $0.ratio > 0 })
    }

    @Test func limbsKeepTheirLengthThroughEveryRep() {
        func length(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }
        for exercise in ExerciseCatalog.all {
            for progress in [0.0, 0.5, 1.0] {
                let body = exercise.motion.skeleton(at: progress)
                #expect(abs(length(body.knee, body.foot) - Skeleton.shinLength) < 0.01)
                #expect(abs(length(body.elbow, body.hand) - Skeleton.forearmLength) < 0.01)
            }
        }
    }

    @Test func anchoredPartsStayPut() {
        let squat = ExerciseMotion.squat
        #expect(squat.skeleton(at: 0).foot == squat.skeleton(at: 1).foot)
        let pullUp = ExerciseMotion.pullUp
        #expect(abs(pullUp.skeleton(at: 0).hand.y - pullUp.skeleton(at: 1).hand.y) < 0.01)
    }
}

struct ProgramCalendarTests {
    @Test func runsThirteenWeeksWithTestsAndADeload() {
        #expect(ProgramCalendar.weeks.count == 13)
        #expect(ProgramCalendar.week(4).kind == .repTest)
        #expect(ProgramCalendar.week(8).kind == .repTest)
        #expect(ProgramCalendar.week(12).kind == .deload)
        #expect(ProgramCalendar.week(13).kind == .maxTest)
        #expect(ProgramCalendar.week(99).number == 13)
    }

    @Test func getsHeavierThroughEachBlock() {
        func percent(_ week: Int) -> Double { ProgramCalendar.week(week).main.percent ?? 0 }
        #expect(percent(1) < percent(3))
        #expect(percent(3) < percent(7))
        #expect(percent(7) < percent(11))
        #expect(percent(12) < percent(11))
    }

    @Test func repsFallAsLoadRises() {
        #expect(ProgramCalendar.week(1).main.reps > ProgramCalendar.week(5).main.reps)
        #expect(ProgramCalendar.week(5).main.reps > ProgramCalendar.week(11).main.reps)
    }
}

struct StrengthProfileTests {
    private let profile = StrengthProfile(bodyweight: 180, experience: .intermediate, maxes: ["bench-press": 225])

    @Test func usesYourNumberOverTheEstimate() {
        #expect(profile.anchorMax(.bench) == 225)
    }

    @Test func estimatesFromBodyweightWhenItHasTo() {
        #expect(abs(profile.anchorMax(.squat) - 243) < 0.001)
    }

    @Test func scalesAccessoriesFromTheirAnchorLift() throws {
        let incline = try #require(ExerciseCatalog.exercise("incline-bench"))
        #expect(profile.oneRepMax(for: incline) == 180)
    }

    @Test func bodyweightWorkHasNoLoad() throws {
        let pullUp = try #require(ExerciseCatalog.exercise("pull-up"))
        #expect(profile.oneRepMax(for: pullUp) == nil)
        #expect(profile.targetWeight(for: pullUp, prescription: Prescription(sets: 3, reps: 8, percent: nil, repsInReserve: 1)) == nil)
    }

    @Test func epleyWorksBothWays() {
        #expect(StrengthProfile.estimatedMax(weight: 200, reps: 1) == 200)
        #expect(abs(StrengthProfile.estimatedMax(weight: 200, reps: 10) - 266.67) < 0.01)
        #expect(StrengthProfile.estimatedMax(weight: 0, reps: 10) == 0)
        #expect(abs(StrengthProfile.shareOfMax(reps: 10) - 0.75) < 0.001)
    }

    @Test func targetsRoundToLoadsYouCanSetUp() throws {
        let bench = try #require(ExerciseCatalog.exercise("bench-press"))
        let target = try #require(profile.targetWeight(for: bench, prescription: Prescription(sets: 4, reps: 10, percent: 0.67, repsInReserve: 1)))
        #expect(target == 150)
        var metric = profile
        metric.usesPounds = false
        #expect(metric.rounded(101.3, for: bench) == 102.5)
    }
}

struct WorkoutPlannerTests {
    private let profile = StrengthProfile(bodyweight: 180, experience: .intermediate, maxes: ["bench-press": 225])

    @Test func recommendsASplitForTheWeek() {
        #expect(SplitLibrary.recommended(daysPerWeek: 3, experience: .beginner, goal: .muscle).id == "full-body")
        #expect(SplitLibrary.recommended(daysPerWeek: 4, experience: .intermediate, goal: .muscle).id == "upper-lower")
        #expect(SplitLibrary.recommended(daysPerWeek: 5, experience: .intermediate, goal: .muscle).id == "bodypart")
        #expect(SplitLibrary.recommended(daysPerWeek: 5, experience: .advanced, goal: .strength).id == "power-hypertrophy")
        #expect(SplitLibrary.recommended(daysPerWeek: 6, experience: .advanced, goal: .muscle).id == "ppl")
    }

    @Test func neverOffersMoreDaysThanYouHave() {
        #expect(SplitLibrary.options(daysPerWeek: 4).allSatisfy { $0.daysPerWeek <= 4 })
        #expect(!SplitLibrary.options(daysPerWeek: 2).isEmpty)
    }

    @Test func aHeavyDayFollowsTheWeeksPercentage() {
        let workout = WorkoutPlanner.workout(split: SplitLibrary.upperLower, week: ProgramCalendar.week(1), dayIndex: 0, profile: profile, goal: .muscle)
        let bench = workout.exercises[0]
        #expect(bench.exercise.id == "bench-press")
        #expect(bench.sets == 4)
        #expect(bench.reps == 10)
        #expect(bench.targetWeight == 150)
    }

    @Test func volumeDaysGoLighterForMoreReps() {
        let heavy = WorkoutPlanner.workout(split: SplitLibrary.pushPullLegs, week: ProgramCalendar.week(1), dayIndex: 0, profile: profile, goal: .muscle)
        let volume = WorkoutPlanner.workout(split: SplitLibrary.pushPullLegs, week: ProgramCalendar.week(1), dayIndex: 3, profile: profile, goal: .muscle)
        #expect(volume.exercises[0].reps > heavy.exercises[0].reps)
    }

    @Test func goalsChangeVolume() {
        func sets(_ goal: LiftGoal) -> Int {
            WorkoutPlanner.workout(split: SplitLibrary.upperLower, week: ProgramCalendar.week(1), dayIndex: 0, profile: profile, goal: goal).exercises.reduce(0) { $0 + $1.sets }
        }
        #expect(sets(.muscle) > sets(.strength))
        #expect(sets(.strength) > sets(.lean))
    }

    @Test func aFocusMuscleGetsExtraSets() {
        let plain = WorkoutPlanner.workout(split: SplitLibrary.upperLower, week: ProgramCalendar.week(1), dayIndex: 2, profile: profile, goal: .muscle)
        let focused = WorkoutPlanner.workout(split: SplitLibrary.upperLower, week: ProgramCalendar.week(1), dayIndex: 2, profile: profile, goal: .muscle, focus: .biceps)
        let index = plain.exercises.firstIndex { $0.exercise.muscle == .biceps }!
        #expect(focused.exercises[index].sets == plain.exercises[index].sets + 1)
    }

    @Test func deloadsIgnoreGoalVolume() {
        let week = WorkoutPlanner.workout(split: SplitLibrary.upperLower, week: ProgramCalendar.week(12), dayIndex: 0, profile: profile, goal: .muscle, focus: .chest)
        #expect(week.exercises.allSatisfy { $0.sets <= 3 })
    }

    @Test func aSwapReplacesTheExerciseWithItsOwnTarget() {
        let key = WorkoutPlanner.slotKey(split: SplitLibrary.upperLower, dayIndex: 0, slotIndex: 0)
        let swapped = WorkoutPlanner.workout(split: SplitLibrary.upperLower, week: ProgramCalendar.week(1), dayIndex: 0, profile: profile, goal: .muscle, swaps: [key: "db-bench-press"])
        #expect(swapped.exercises[0].exercise.id == "db-bench-press")
        #expect(swapped.exercises[0].targetWeight == 120)
    }

    @Test func repTestsMarkTheMainLift() {
        let test = WorkoutPlanner.workout(split: SplitLibrary.upperLower, week: ProgramCalendar.week(4), dayIndex: 0, profile: profile, goal: .muscle)
        #expect(test.exercises[0].isRepTest)
        #expect(!test.exercises.last!.isRepTest)
    }

    @Test func aMissedDayWaitsForYou() {
        let split = SplitLibrary.upperLower
        #expect(WorkoutPlanner.nextSession(split: split, completed: [])?.week == 1)
        let next = WorkoutPlanner.nextSession(split: split, completed: ["1-0", "1-1"])
        #expect(next?.week == 1)
        #expect(next?.dayIndex == 2)
        let wrapped = WorkoutPlanner.nextSession(split: split, completed: ["1-0", "1-1", "1-2", "1-3"])
        #expect(wrapped?.week == 2)
        #expect(wrapped?.dayIndex == 0)
    }

    @Test func theProgramEnds() {
        let split = SplitLibrary.fullBody
        var all = Set<String>()
        for week in 1 ... 13 { for day in split.days.indices { all.insert("\(week)-\(day)") } }
        #expect(WorkoutPlanner.nextSession(split: split, completed: all) == nil)
    }

    @Test func quickWorkoutsFitTheTimeAndEquipment() {
        let workout = QuickWorkoutBuilder.workout(muscles: [.chest, .back], minutes: 48, profile: profile, goal: .muscle, equipment: [.dumbbell, .cable])
        #expect(workout.count <= 6)
        #expect(!workout.isEmpty)
        #expect(workout.allSatisfy { [.dumbbell, .cable].contains($0.exercise.equipment) })
        #expect(Set(workout.map(\.exercise.muscle)) == [.chest, .back])
        #expect(QuickWorkoutBuilder.workout(muscles: [], minutes: 30, profile: profile, goal: .muscle).isEmpty)
    }
}

struct NutritionPlanTests {
    @Test func muscleGainEatsMoreThanStayingLean() {
        let muscle = NutritionPlan(bodyweight: 180, usesPounds: true, goal: .muscle, trainingDays: 4)
        let lean = NutritionPlan(bodyweight: 180, usesPounds: true, goal: .lean, trainingDays: 4)
        #expect(muscle.training.calories > lean.training.calories)
        #expect(lean.training.protein > muscle.training.protein)
    }

    @Test func trainingDaysGetMoreFoodThanRestDays() {
        let plan = NutritionPlan(bodyweight: 180, usesPounds: true, goal: .muscle, trainingDays: 4)
        #expect(plan.training.calories - plan.rest.calories == 300)
        #expect(plan.training.protein == 180)
        #expect(plan.training.carbohydrates > plan.rest.carbohydrates)
    }

    @Test func theWeekAveragesOutToTheTarget() {
        let plan = NutritionPlan(bodyweight: 200, usesPounds: true, goal: .muscle, trainingDays: 5)
        let week = plan.training.calories * 5 + plan.rest.calories * 2
        #expect(abs(week / 7 - plan.dailyAverage) <= 10)
    }

    @Test func kilogramsMeanTheSameAsPounds() {
        let pounds = NutritionPlan(bodyweight: 176.4, usesPounds: true, goal: .muscle, trainingDays: 4)
        let kilograms = NutritionPlan(bodyweight: 80, usesPounds: false, goal: .muscle, trainingDays: 4)
        #expect(abs(pounds.training.calories - kilograms.training.calories) <= 10)
    }

    @Test func macrosAddUpToTheCalories() {
        let goals = NutritionPlan(bodyweight: 180, usesPounds: true, goal: .muscle, trainingDays: 4).training
        #expect(abs(goals.protein * 4 + goals.carbohydrates * 4 + goals.fat * 9 - goals.calories) < 10)
    }
}

@MainActor
struct ResolvedGoalsTests {
    private let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!
    private let sunday = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))!

    private func plan(matches: Bool) -> LiftPlan {
        LiftPlan(goal: .muscle, experience: .intermediate, splitID: "upper-lower", weekdays: [2, 3, 5, 6], bodyweight: 180, usesPounds: true, focus: nil, matchesNutrition: matches)
    }

    @Test func profileGoalsApplyUntilYouTurnItOn() {
        let user = User(name: "Sam", calorie_goal: 2222, protein_goal: 100, carb_goal: 200, fat_goal: 60)
        #expect(DayGoals.resolved(user: user, plan: plan(matches: false), on: monday).calories == 2222)
        #expect(DayGoals.resolved(user: user, plan: nil, on: monday).calories == 2222)
    }

    @Test func goalsFollowTheSchedule() {
        let user = User(name: "Sam", calorie_goal: 2222, protein_goal: 100, carb_goal: 200, fat_goal: 60)
        let matched = plan(matches: true)
        #expect(DayGoals.resolved(user: user, plan: matched, on: monday) == matched.nutrition.training)
        #expect(DayGoals.resolved(user: user, plan: matched, on: sunday) == matched.nutrition.rest)
        #expect(matched.goalCaption(on: sunday) == "Rest day goals")
    }

    @Test func aWidgetRollsOverToTheNextDaysGoals() {
        let matched = plan(matches: true)
        let friday = WidgetSync.snapshot(foods: [], user: nil, plan: matched, at: monday)
        #expect(friday.calorieGoal == matched.nutrition.training.calories)
        #expect(friday.cleared(for: sunday).calorieGoal == matched.nutrition.rest.calories)
    }
}

struct SelfPacedTests {
    private let profile = StrengthProfile(bodyweight: 180, experience: .intermediate, maxes: ["bench-press": 225])

    @Test func logsEverySetAsPlanned() {
        let workout = WorkoutPlanner.workout(split: SplitLibrary.upperLower, week: ProgramCalendar.week(1), dayIndex: 0, profile: profile, goal: .muscle)
        let entries = SelfPacedLog.entries(for: workout.exercises, testReps: [:])
        let bench = entries[workout.exercises[0].id]
        #expect(bench?.count == 4)
        #expect(bench?.allSatisfy { $0.isDone && $0.weight == 150 && $0.reps == 10 } == true)
    }

    @Test func aRepTestUsesTheRealNumberOnTheLastSet() {
        let workout = WorkoutPlanner.workout(split: SplitLibrary.upperLower, week: ProgramCalendar.week(4), dayIndex: 0, profile: profile, goal: .muscle)
        let id = workout.exercises[0].id
        let bench = SelfPacedLog.entries(for: workout.exercises, testReps: [id: 9])[id]
        #expect(bench?.last?.reps == 9)
        #expect(bench?.first?.reps == workout.exercises[0].reps)
    }
}

struct LiftSnapshotTests {
    private let snapshot = LiftSnapshot(week: 3, totalWeeks: 13, phase: "Foundation", dayName: "Upper", focus: "", minutes: 60, lines: [], weekdays: [2], lastTrained: nil)
    private let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!
    private let sunday = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))!

    @Test func knowsWhatKindOfDayItIs() {
        #expect(snapshot.status(on: monday) == .today)
        #expect(snapshot.status(on: sunday) == .rest)
        var trained = snapshot
        trained.lastTrained = monday
        #expect(trained.status(on: monday) == .done)
    }

    @Test func survivesBeingSaved() {
        let defaults = UserDefaults(suiteName: "k-cal-tests-\(UUID().uuidString)")!
        LiftSnapshot.save(snapshot, defaults: defaults)
        #expect(LiftSnapshot.load(defaults: defaults) == snapshot)
        LiftSnapshot.save(nil, defaults: defaults)
        #expect(LiftSnapshot.load(defaults: defaults) == nil)
    }
}

struct FootDirectionTests {
    private func toe(_ motion: ExerciseMotion, at progress: Double = 0) -> CGVector {
        let body = motion.skeleton(at: progress)
        let tip = motion.toe(foot: body.foot, knee: body.knee)
        return CGVector(dx: tip.x - body.foot.x, dy: tip.y - body.foot.y)
    }

    @Test func standingToesPointTheWayTheFigureFaces() {
        #expect(toe(.squat).dx > 5)
        #expect(toe(.overheadPress).dx > 5)
    }

    @Test func onYourBackWithHeadRightToesPointLeft() {
        #expect(toe(.benchPress).dx < -5)
        #expect(toe(.inclinePress).dx < -5)
        #expect(toe(.skullCrusher).dx < -5)
    }

    @Test func faceDownToesPointAtTheFloor() {
        #expect(toe(.legCurl).dy > 5)
        #expect(toe(.pushUp).dy > 5)
        #expect(toe(.plank).dy > 5)
    }

    @Test func toesStayInsideTheFrame() {
        for exercise in ExerciseCatalog.all {
            let motion = exercise.motion
            for progress in stride(from: 0.0, through: 1.0, by: 0.25) {
                let body = motion.skeleton(at: progress)
                #expect(motion.extent.insetBy(dx: -0.01, dy: -0.01).contains(motion.toe(foot: body.foot, knee: body.knee)), "\(exercise.name)")
            }
        }
    }
}

struct PushUpMotionTests {
    @Test func theToesAndHandsStayPlanted() {
        let motion = ExerciseMotion.pushUp
        let top = motion.skeleton(at: 0)
        for frame in 0 ... 20 {
            let body = motion.skeleton(at: Double(frame) / 20)
            #expect(body.foot == top.foot)
            #expect(hypot(body.hand.x - top.hand.x, body.hand.y - top.hand.y) < 0.6)
        }
    }

    @Test func theChestGoesDownAndComesBackOverTheHands() {
        let motion = ExerciseMotion.pushUp
        let top = motion.skeleton(at: 0)
        let bottom = motion.skeleton(at: 1)
        #expect(top.hand.y - top.shoulder.y > 25)
        #expect(bottom.hand.y - bottom.shoulder.y > 10 && bottom.hand.y - bottom.shoulder.y < 18)
        // The arms stay below the shoulders the whole way.
        for frame in 0 ... 20 {
            let body = motion.skeleton(at: Double(frame) / 20)
            #expect(body.hand.y > body.shoulder.y)
        }
    }
}

struct ArmSweepTests {
    @Test func cableFlyArmsNeverGoOverhead() {
        for frame in 0 ... 20 {
            let body = ExerciseMotion.cableFly.skeleton(at: Double(frame) / 20)
            #expect(body.elbow.y > body.head.y)
        }
    }

    @Test func reverseFlyArmsStayBehindTheChest() {
        for frame in 0 ... 20 {
            let body = ExerciseMotion.reverseFly.skeleton(at: Double(frame) / 20)
            #expect(body.elbow.x <= body.shoulder.x + 1.5)
        }
    }
}

struct MotionTempoTests {
    @Test func aRepPausesThenReturnsAndStaysInRange() {
        #expect(ExerciseMotion.progress(atPhase: 0) == 0)
        #expect(ExerciseMotion.progress(atPhase: 0.46) == 1)
        #expect(ExerciseMotion.progress(atPhase: 0.97) == 0)
        for step in 0 ..< 200 {
            let value = ExerciseMotion.progress(atPhase: Double(step) / 200)
            #expect(value >= 0 && value <= 1)
        }
    }

    @Test func thereAreNoJumps() {
        var previous = ExerciseMotion.progress(atPhase: 0)
        for step in 1 ..< 1000 {
            let value = ExerciseMotion.progress(atPhase: Double(step) / 1000)
            #expect(abs(value - previous) < 0.02)
            previous = value
        }
    }

    @Test func aBarTravelsInAStraightLine() {
        let motion = ExerciseMotion.benchPress
        let start = motion.skeleton(at: 0).hand
        let end = motion.skeleton(at: 1).hand
        let middle = motion.skeleton(at: 0.5).hand
        #expect(abs(middle.x - (start.x + end.x) / 2) < 0.2)
        #expect(abs(middle.y - (start.y + end.y) / 2) < 0.2)
    }

    @Test func noJointJumpsBetweenFrames() {
        func step(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }
        for exercise in ExerciseCatalog.all {
            var previous = exercise.motion.skeleton(at: 0)
            for frame in 1 ... 120 {
                let body = exercise.motion.skeleton(at: Double(frame) / 120)
                for (a, b) in [(previous.elbow, body.elbow), (previous.hand, body.hand), (previous.knee, body.knee), (previous.hip, body.hip)] {
                    #expect(step(a, b) < 3, "\(exercise.name) at frame \(frame)")
                }
                previous = body
            }
        }
    }

    @Test func armsKeepTheirLengthOnAStraightPath() {
        for exercise in ExerciseCatalog.all where exercise.motion.straightHandPath {
            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                let body = exercise.motion.skeleton(at: progress)
                #expect(abs(hypot(body.shoulder.x - body.elbow.x, body.shoulder.y - body.elbow.y) - Skeleton.upperArmLength) < 0.05, "\(exercise.name)")
                #expect(abs(hypot(body.elbow.x - body.hand.x, body.elbow.y - body.hand.y) - Skeleton.forearmLength) < 0.05, "\(exercise.name)")
            }
        }
    }
}

struct LiftRecordsTests {
    private func done(_ weight: Double, _ reps: Int) -> SetEntry {
        SetEntry(weight: weight, reps: reps, isDone: true)
    }

    @Test func aBetterSetBeatsTheOldMax() {
        let records = LiftRecords.records(from: ["bench-press": [done(200, 5)]], known: ["bench-press": 225], repTests: [])
        #expect(records.first?.previous == 225)
        #expect(abs((records.first?.oneRepMax ?? 0) - 233.33) < 0.01)
    }

    @Test func aWeakerSetChangesNothing() {
        #expect(LiftRecords.records(from: ["bench-press": [done(100, 5)]], known: ["bench-press": 225], repTests: []).isEmpty)
    }

    @Test func aPlannedSetCannotLowerAnEstimate() {
        // 115 x 10 predicts about 153, but that set stopped short of failure on purpose.
        #expect(LiftRecords.records(from: ["bench-press": [done(115, 10)]], known: ["bench-press": 180], repTests: []).isEmpty)
    }

    @Test func aRepTestSetsTheNumberEvenIfLower() {
        let records = LiftRecords.records(from: ["bench-press": [done(150, 5)]], known: ["bench-press": 225], repTests: ["bench-press"])
        #expect(records.first?.oneRepMax == 175)
    }

    @Test func unfinishedSetsDoNotCount() {
        #expect(LiftRecords.records(from: ["bench-press": [SetEntry(weight: 500, reps: 5)]], known: [:], repTests: []).isEmpty)
    }
}

@MainActor
struct LiftStorageTests {
    private let context: ModelContext

    init() throws {
        let container = try ModelContainer(
            for: LiftPlan.self, LiftMax.self, LiftSwap.self, WorkoutLog.self, SetLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    @Test func aPlanTurnsIntoAProfile() {
        let plan = LiftPlan(goal: .muscle, experience: .advanced, splitID: "ppl", weekdays: [2, 3], bodyweight: 200, usesPounds: true, focus: .biceps)
        context.insert(plan)
        let profile = plan.profile(maxes: [LiftMax(exerciseID: "deadlift", oneRepMax: 500)])
        #expect(profile.anchorMax(.deadlift) == 500)
        #expect(profile.experience == .advanced)
        #expect(plan.split.id == "ppl")
        #expect(plan.focus == .biceps)
    }

    @Test func workoutsFromAnEarlierRunDoNotCount() {
        let plan = LiftPlan(goal: .muscle, experience: .advanced, splitID: "ppl", weekdays: [2, 3], bodyweight: 200, usesPounds: true, focus: nil)
        let earlier = WorkoutLog(date: plan.started.addingTimeInterval(-3600), title: "Old", week: 1, dayIndex: 0, minutes: 50)
        let later = WorkoutLog(date: plan.started.addingTimeInterval(3600), title: "New", week: 1, dayIndex: 1, minutes: 50)
        #expect(plan.completedSessions(in: [earlier, later]) == ["1-1"])
    }

    @Test func aLoggedSessionCountsAsDone() throws {
        let log = WorkoutLog(date: Date(), title: "Upper", week: 2, dayIndex: 1, minutes: 50)
        context.insert(log)
        let set = SetLog(exerciseID: "bench-press", setNumber: 1, weight: 135, reps: 8)
        context.insert(set)
        set.workout = log
        try context.save()
        #expect(log.sessionKey == "2-1")
        #expect(log.sets.count == 1)
        #expect(WorkoutLog(date: Date(), title: "Quick", week: nil, dayIndex: nil, minutes: 1).sessionKey == nil)
    }
}
