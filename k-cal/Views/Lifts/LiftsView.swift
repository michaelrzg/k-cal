//
//  LiftsView.swift
//  k-cal
//
//  The Lifts tab: today's session, where you are in the program, and your numbers.
//

import SwiftData
import SwiftUI

struct LiftsView: View {
    @Binding var showingProfile: Bool
    @Environment(\.modelContext) private var context
    @Query(sort: \LiftPlan.started, order: .reverse) private var plans: [LiftPlan]
    @Query private var maxes: [LiftMax]
    @Query private var swaps: [LiftSwap]
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]
    @State private var showingSetup = false
    @State private var startsNewProgram = false
    @State private var activeWorkout: ActiveSession?

    private var plan: LiftPlan? {
        plans.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let plan {
                    hub(plan)
                } else {
                    introduction
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Lifts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ProfileButton(showingProfile: $showingProfile) }
                if plan != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSetup = true } label: { Image(systemName: "slider.horizontal.3") }
                            .accessibilityLabel("Change plan")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingSetup, onDismiss: { startsNewProgram = false }) {
            LiftSetupView(existing: plan, startsOver: startsNewProgram)
        }
        .fullScreenCover(item: $activeWorkout) { session in ActiveWorkoutView(session: session) }
    }

    private var introduction: some View {
        ScrollView {
            VStack(spacing: 18) {
                ExerciseAnimationView(exercise: ExerciseCatalog.exercise("back-squat")!)
                    .frame(height: 200)
                Text("Train with a plan").font(.title2.bold())
                Text("Tell us your goal and schedule. You'll get a 13-week program built around your bodyweight and strength, with target weights for every set.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 12) {
                    point("calendar", "Three training blocks that build to a max test")
                    point("scalemass", "Target weights from your one-rep maxes")
                    point("arrow.triangle.2.circlepath", "Swap any exercise for an alternative")
                    point("trophy", "Automatic personal records as you log")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                Button { showingSetup = true } label: {
                    Text("Build My Program").font(.headline).foregroundStyle(Theme.onBrand).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 14))
            }
            .padding()
        }
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        Label { Text(text).font(.subheadline) } icon: { Image(systemName: symbol).foregroundStyle(Theme.brand) }
    }

    private func hub(_ plan: LiftPlan) -> some View {
        let profile = plan.profile(maxes: maxes)
        let swapMap = Dictionary(swaps.map { ($0.slotKey, $0.exerciseID) }, uniquingKeysWith: { _, new in new })
        let completed = plan.completedSessions(in: logs)
        let split = plan.split
        let next = WorkoutPlanner.nextSession(split: split, completed: completed)
        let workout = next.map {
            WorkoutPlanner.workout(split: split, week: ProgramCalendar.week($0.week), dayIndex: $0.dayIndex, profile: profile, goal: plan.goal, swaps: swapMap, focus: plan.focus)
        }
        let isTrainingDay = plan.weekdays.contains(Calendar.current.component(.weekday, from: Date()))
        let trainedToday = logs.first.map { Calendar.current.isDateInToday($0.date) } ?? false

        return ScrollView {
            VStack(spacing: 14) {
                if let workout {
                    todayCard(workout, plan: plan, isTrainingDay: isTrainingDay, trainedToday: trainedToday)
                    programStrip(current: workout.week, plan: plan)
                } else {
                    finishedCard
                }
                HStack(spacing: 10) {
                    NavigationLink { ProgramView(plan: plan) } label: { LinkTile(title: "Program", symbol: "calendar") }
                    NavigationLink { QuickWorkoutView(plan: plan) { activeWorkout = $0 } } label: { LinkTile(title: "Quick Lift", symbol: "bolt") }
                    NavigationLink { ExerciseLibraryView(plan: plan) } label: { LinkTile(title: "Exercises", symbol: "list.bullet") }
                }
                .buttonStyle(.plain)
                numbersCard(plan: plan, profile: profile)
                if !logs.isEmpty { recentCard(plan: plan) }
            }
            .padding()
        }
    }

    private func todayCard(_ workout: PlannedWorkout, plan: LiftPlan, isTrainingDay: Bool, trainedToday: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(trainedToday ? "Up next" : isTrainingDay ? "Today" : "Rest day, up next")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.brand)
                Spacer()
                Text("Week \(workout.week.number) of \(ProgramCalendar.weekCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.day.name).font(.title2.bold())
                    Text(workout.day.focus).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(workout.exercises.count) exercises, about \(workout.estimatedMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let first = workout.exercises.first {
                    ExerciseAnimationView(exercise: first.exercise).frame(width: 84, height: 84)
                }
            }
            Text(workout.week.note).font(.footnote).foregroundStyle(.secondary)
            HStack {
                NavigationLink {
                    WorkoutPreviewView(plan: plan, week: workout.week.number, dayIndex: workout.dayIndex) { activeWorkout = $0 }
                } label: {
                    Text("View").frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                Button {
                    activeWorkout = ActiveSession(workout: workout, plan: plan)
                } label: {
                    Text("Start Workout").font(.headline).foregroundStyle(Theme.onBrand).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var finishedCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(Theme.brand)
            Text("Program complete").font(.title3.bold())
            Text("All 13 weeks done. Your new maxes are saved, so start another round when you're ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Start a New Program") {
                startsNewProgram = true
                showingSetup = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private func programStrip(current: ProgramWeek, plan: LiftPlan) -> some View {
        NavigationLink { ProgramView(plan: plan) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(current.phase).font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                HStack(spacing: 3) {
                    ForEach(ProgramCalendar.weeks) { week in
                        Capsule()
                            .fill(week.number <= current.number ? Theme.brand : Theme.brand.opacity(0.18))
                            .frame(height: week.kind == .training ? 8 : 12)
                    }
                }
                .frame(height: 12)
            }
            .padding()
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(current.phase) block, week \(current.number) of 13")
    }

    private func numbersCard(plan: LiftPlan, profile: StrengthProfile) -> some View {
        NavigationLink { LiftProgressView(plan: plan) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Your numbers").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                ForEach([AnchorLift.squat, .bench, .deadlift, .press]) { lift in
                    HStack {
                        Text(lift.title).font(.subheadline)
                        Spacer()
                        Text(LiftFormat.weight(profile.rounded(profile.anchorMax(lift), for: ExerciseCatalog.exercise(lift.exerciseID)!), unit: plan.unit))
                            .font(.numeral(17, weight: .semibold))
                            .monospacedDigit()
                        if profile.maxes[lift.exerciseID] == nil {
                            Text("est.").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func recentCard(plan: LiftPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent").font(.headline)
            ForEach(logs.prefix(4)) { log in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(log.title).font(.subheadline)
                        Text(log.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(log.sets.count) sets").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

private struct LinkTile: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Theme.brand).frame(height: 26)
            Text(title).font(.footnote.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
