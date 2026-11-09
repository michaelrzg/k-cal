//
//  WorkoutViews.swift
//  k-cal
//
//  Looking at the program: the 13 weeks, one session, one exercise, and the exercise library.
//

import SwiftData
import SwiftUI

/// The whole program, block by block.
struct ProgramView: View {
    let plan: LiftPlan

    @Query private var logs: [WorkoutLog]
    @State private var activeWorkout: ActiveSession?

    var body: some View {
        let completed = plan.completedSessions(in: logs)
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.split.name).font(.title3.bold())
                    Text("Three blocks that get heavier. Rep tests in weeks 4 and 8 update your numbers, then a deload sets up your max test in week 13.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            ForEach(ProgramCalendar.weeks) { week in
                Section {
                    ForEach(Array(plan.split.days.enumerated()), id: \.offset) { index, day in
                        NavigationLink {
                            WorkoutPreviewView(plan: plan, week: week.number, dayIndex: index) { activeWorkout = $0 }
                        } label: {
                            HStack {
                                Image(systemName: completed.contains("\(week.number)-\(index)") ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(completed.contains("\(week.number)-\(index)") ? Theme.brand : Color.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(day.name)
                                    Text(day.focus).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Week \(week.number): \(week.phase)").textCase(nil)
                } footer: {
                    Text("\(week.note) Main lifts: \(week.main.sets) x \(week.main.reps) at \(Int(((week.main.percent ?? 0) * 100).rounded()))%.")
                }
                .listRowBackground(Theme.card)
            }
        }
        .themedList()
        .navigationTitle("13-Week Program")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $activeWorkout) { ActiveWorkoutView(session: $0) }
    }
}

/// One session, with targets, swaps and a start button.
struct WorkoutPreviewView: View {
    let plan: LiftPlan
    let week: Int
    let dayIndex: Int
    let onStart: (ActiveSession) -> Void

    @Environment(\.modelContext) private var context
    @Query private var maxes: [LiftMax]
    @Query private var swaps: [LiftSwap]

    private var workout: PlannedWorkout {
        WorkoutPlanner.workout(
            split: plan.split, week: ProgramCalendar.week(week), dayIndex: dayIndex, profile: plan.profile(maxes: maxes), goal: plan.goal,
            swaps: Dictionary(swaps.map { ($0.slotKey, $0.exerciseID) }, uniquingKeysWith: { _, new in new }), focus: plan.focus
        )
    }

    var body: some View {
        let workout = workout
        List {
            Section {
                ForEach(workout.exercises) { item in
                    NavigationLink {
                        ExerciseDetailView(exercise: item.exercise, unit: plan.unit, plan: plan, slotKey: item.slotKey, planned: item)
                    } label: {
                        PlannedExerciseRow(item: item, unit: plan.unit)
                    }
                }
            } header: {
                Text("\(workout.exercises.count) exercises, about \(workout.estimatedMinutes) min").textCase(nil)
            } footer: {
                Text(workout.week.note)
            }
            .listRowBackground(Theme.card)
        }
        .themedList()
        .navigationTitle(workout.day.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                onStart(ActiveSession(workout: workout, plan: plan))
            } label: {
                Text("Start Workout").font(.headline).foregroundStyle(Theme.onBrand).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .padding()
            .background(Theme.background.ignoresSafeArea())
        }
    }
}

struct PlannedExerciseRow: View {
    let item: PlannedExercise
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            ExerciseAnimationView(exercise: item.exercise, isPlaying: false)
                .frame(width: 52, height: 52)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.exercise.name).lineLimit(2)
                Text(LiftFormat.prescription(item, unit: unit)).font(.subheadline).foregroundStyle(Theme.brand).monospacedDigit()
                if item.isRepTest {
                    Text("Last set: as many good reps as you can").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// How to do a lift, with its alternatives.
struct ExerciseDetailView: View {
    let exercise: Exercise
    let unit: String
    let plan: LiftPlan?
    var slotKey: String?
    var planned: PlannedExercise?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var swaps: [LiftSwap]
    @Query private var maxes: [LiftMax]
    @Query private var sets: [SetLog]

    private var alternatives: [Exercise] {
        ExerciseCatalog.alternatives(to: exercise)
    }

    private var bestSet: SetLog? {
        sets.filter { $0.exerciseID == exercise.id }.max { $0.estimatedMax < $1.estimatedMax }
    }

    var body: some View {
        List {
            Section {
                ExerciseAnimationView(exercise: exercise)
                    .frame(maxWidth: 260)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .listRowBackground(Theme.card)
            Section {
                LabeledContent("Trains", value: exercise.muscle.rawValue)
                if !exercise.secondary.isEmpty {
                    LabeledContent("Also works", value: exercise.secondary.map(\.rawValue).joined(separator: ", "))
                }
                LabeledContent("Equipment", value: exercise.equipment.rawValue)
                if let planned {
                    LabeledContent("Today", value: LiftFormat.prescription(planned, unit: unit))
                    Text(LiftFormat.reserve(planned.repsInReserve)).font(.footnote).foregroundStyle(.secondary)
                }
                if let plan, let max = plan.profile(maxes: maxes).oneRepMax(for: exercise) {
                    LabeledContent("Estimated 1RM", value: LiftFormat.weight(max.rounded(), unit: unit))
                }
                if let bestSet {
                    LabeledContent("Best set", value: "\(LiftFormat.weight(bestSet.weight, unit: unit)) x \(bestSet.reps)")
                }
            }
            .listRowBackground(Theme.card)
            Section("How to do it") {
                ForEach(Array(exercise.cues.enumerated()), id: \.offset) { index, cue in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)").font(.numeral(15, weight: .semibold)).foregroundStyle(Theme.brand)
                        Text(cue).font(.subheadline)
                    }
                }
            }
            .listRowBackground(Theme.card)
            if !alternatives.isEmpty {
                Section(slotKey == nil ? "Alternatives" : "Swap for") {
                    ForEach(alternatives) { option in
                        if let slotKey {
                            Button { swap(slotKey, to: option) } label: { row(option) }
                                .buttonStyle(.plain)
                        } else {
                            NavigationLink { ExerciseDetailView(exercise: option, unit: unit, plan: plan) } label: { row(option) }
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
        }
        .themedList()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ option: Exercise) -> some View {
        HStack(spacing: 12) {
            ExerciseAnimationView(exercise: option, isPlaying: false)
                .frame(width: 44, height: 44)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(option.name)
                Text(option.equipment.rawValue).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func swap(_ key: String, to option: Exercise) {
        if let existing = swaps.first(where: { $0.slotKey == key }) {
            existing.exerciseID = option.id
        } else {
            context.insert(LiftSwap(slotKey: key, exerciseID: option.id))
        }
        try? context.save()
        dismiss()
    }
}

struct ExerciseLibraryView: View {
    let plan: LiftPlan

    @State private var muscle: Muscle?
    @State private var searchText = ""

    private var exercises: [Exercise] {
        ExerciseCatalog.all.filter { exercise in
            (muscle == nil || exercise.muscle == muscle)
                && (searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip("All", isOn: muscle == nil) { muscle = nil }
                        ForEach(Muscle.allCases) { option in
                            chip(option.rawValue, isOn: muscle == option) { muscle = option }
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                ForEach(exercises) { exercise in
                    NavigationLink { ExerciseDetailView(exercise: exercise, unit: plan.unit, plan: plan) } label: {
                        HStack(spacing: 12) {
                            ExerciseAnimationView(exercise: exercise, isPlaying: false)
                                .frame(width: 48, height: 48)
                                .background(Theme.background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(exercise.name)
                                Text("\(exercise.muscle.rawValue), \(exercise.equipment.rawValue)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listRowBackground(Theme.card)
        }
        .themedList()
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOn ? Theme.onBrand : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isOn ? Theme.brand : Theme.card, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Builds a one-off session for the muscles and time you've got.
struct QuickWorkoutView: View {
    let plan: LiftPlan
    let onStart: (ActiveSession) -> Void

    @Query private var maxes: [LiftMax]
    @State private var selected: Set<Muscle> = [.chest, .back]
    @State private var minutes = 45
    @State private var equipment = Set(Equipment.allCases)

    private var exercises: [PlannedExercise] {
        QuickWorkoutBuilder.workout(muscles: Muscle.allCases.filter(selected.contains), minutes: minutes, profile: plan.profile(maxes: maxes), goal: plan.goal, equipment: equipment)
    }

    var body: some View {
        let exercises = exercises
        List {
            Section("Train") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Muscle.allCases) { muscle in
                        toggle(muscle.rawValue, isOn: selected.contains(muscle)) {
                            if selected.contains(muscle) { selected.remove(muscle) } else { selected.insert(muscle) }
                        }
                    }
                }
            }
            .listRowBackground(Theme.card)
            Section("Time") {
                Picker("Minutes", selection: $minutes) {
                    ForEach([30, 45, 60, 75], id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .listRowBackground(Theme.card)
            Section("Equipment") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Equipment.allCases) { item in
                        toggle(item.rawValue, isOn: equipment.contains(item)) {
                            if equipment.contains(item) { equipment.remove(item) } else { equipment.insert(item) }
                        }
                    }
                }
            }
            .listRowBackground(Theme.card)
            if !exercises.isEmpty {
                Section("Your workout") {
                    ForEach(exercises) { PlannedExerciseRow(item: $0, unit: plan.unit) }
                }
                .listRowBackground(Theme.card)
            }
        }
        .themedList()
        .navigationTitle("Quick Lift")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                onStart(ActiveSession(title: "Quick Lift", exercises: exercises, unit: plan.unit, week: nil, dayIndex: nil, isSelfPaced: plan.isSelfPaced))
            } label: {
                Text("Start Workout").font(.headline).foregroundStyle(Theme.onBrand).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .disabled(exercises.isEmpty)
            .padding()
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private func toggle(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOn ? Theme.onBrand : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isOn ? Theme.brand : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
