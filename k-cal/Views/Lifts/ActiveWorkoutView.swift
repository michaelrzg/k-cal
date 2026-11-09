//
//  ActiveWorkoutView.swift
//  k-cal
//
//  The gym screen: log each set, rest between them, and finish with any new records.
//

import SwiftData
import SwiftUI

struct ActiveSession: Identifiable {
    let id = UUID()
    let title: String
    let exercises: [PlannedExercise]
    let unit: String
    let week: Int?
    let dayIndex: Int?
    /// Just the sets on show: no timer, nothing to tick.
    let isSelfPaced: Bool

    init(title: String, exercises: [PlannedExercise], unit: String, week: Int?, dayIndex: Int?, isSelfPaced: Bool) {
        self.title = title
        self.exercises = exercises
        self.unit = unit
        self.week = week
        self.dayIndex = dayIndex
        self.isSelfPaced = isSelfPaced
    }

    init(workout: PlannedWorkout, plan: LiftPlan) {
        self.init(title: workout.day.name, exercises: workout.exercises, unit: plan.unit, week: workout.week.number, dayIndex: workout.dayIndex, isSelfPaced: plan.isSelfPaced)
    }
}

/// A self-paced workout, logged as planned. A rep test is the exception, because your maxes need the real number.
enum SelfPacedLog {
    static func entries(for exercises: [PlannedExercise], testReps: [String: Int]) -> [String: [SetEntry]] {
        var entries: [String: [SetEntry]] = [:]
        for item in exercises {
            var sets = (0 ..< item.sets).map { _ in SetEntry(weight: item.targetWeight ?? 0, reps: item.reps, isDone: true) }
            if let reps = testReps[item.id], reps > 0, !sets.isEmpty { sets[sets.count - 1].reps = reps }
            entries[item.id] = sets
        }
        return entries
    }
}

/// A set as it's being logged.
struct SetEntry: Identifiable, Equatable {
    let id = UUID()
    var weight: Double
    var reps: Int
    var isDone = false
}

/// The records a workout set: one-rep maxes it beat, or replaced in a test.
enum LiftRecords {
    struct Record: Equatable, Identifiable {
        let exerciseID: String
        let oneRepMax: Double
        let previous: Double?

        var id: String { exerciseID }
    }

    /// The best estimated max per exercise where it beats what's known. A rep test counts even if lower, because
    /// that's what it's there to find out.
    static func records(from entries: [String: [SetEntry]], known: [String: Double], repTests: Set<String>) -> [Record] {
        entries.compactMap { id, sets in
            let best = sets.filter(\.isDone).map { StrengthProfile.estimatedMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            guard best > 0 else { return nil }
            let previous = known[id]
            if repTests.contains(id) || previous.map({ best > $0 }) ?? true {
                return Record(exerciseID: id, oneRepMax: best, previous: previous)
            }
            return nil
        }
        .sorted { $0.exerciseID < $1.exerciseID }
    }
}

struct ActiveWorkoutView: View {
    let session: ActiveSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var maxes: [LiftMax]
    @Query(sort: \LiftPlan.started, order: .reverse) private var plans: [LiftPlan]
    @State private var entries: [String: [SetEntry]]
    @State private var current = 0
    @State private var started = Date()
    @State private var restEnds: Date?
    @State private var restLength = 90
    @State private var confirmingQuit = false
    @State private var finishedRecords: [LiftRecords.Record]?
    @State private var testReps: [String: Int] = [:]

    init(session: ActiveSession) {
        self.session = session
        var entries: [String: [SetEntry]] = [:]
        for item in session.exercises {
            entries[item.id] = (0 ..< item.sets).map { _ in SetEntry(weight: item.targetWeight ?? 0, reps: item.reps) }
        }
        _entries = State(initialValue: entries)
    }

    private var item: PlannedExercise {
        session.exercises[current]
    }

    private var doneSets: Int {
        entries.values.joined().filter(\.isDone).count
    }

    private var totalSets: Int {
        entries.values.joined().count
    }

    var body: some View {
        NavigationStack {
            Group {
                if let finishedRecords {
                    summary(finishedRecords)
                } else if session.isSelfPaced {
                    selfPaced
                } else {
                    logging
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(finishedRecords == nil ? session.title : "Workout Done")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if finishedRecords == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Quit") { confirmingQuit = true }
                    }
                    if !session.isSelfPaced {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Finish", action: finish).bold().disabled(doneSets == 0)
                        }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { hideKeyboard() }
                    }
                }
            }
            .confirmationDialog("Quit this workout?", isPresented: $confirmingQuit, titleVisibility: .visible) {
                Button("Quit Without Saving", role: .destructive) { dismiss() }
                Button("Keep Going", role: .cancel) {}
            }
        }
        .sensoryFeedback(.success, trigger: doneSets)
    }

    private var selfPaced: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(session.exercises) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            ExerciseAnimationView(exercise: item.exercise)
                                .frame(width: 72, height: 72)
                                .background(Theme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.exercise.name).font(.headline).lineLimit(2)
                                Text(LiftFormat.prescription(item, unit: session.unit))
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.brand)
                                Text(LiftFormat.reserve(item.repsInReserve)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        if item.isRepTest {
                            HStack {
                                Text("Reps on your last set").font(.subheadline)
                                Spacer()
                                TextField("\(item.reps)", value: Binding(get: { testReps[item.id] }, set: { testReps[item.id] = $0 }), format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .font(.numeral(18, weight: .semibold))
                                    .frame(width: 64, height: 36)
                                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(action: finish) {
                Text("Finish Workout").font(.headline).foregroundStyle(Theme.onBrand).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .padding()
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private var logging: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(doneSets), total: Double(max(totalSets, 1))).tint(Theme.brand)
            ScrollView {
                VStack(spacing: 14) {
                    ExerciseAnimationView(exercise: item.exercise)
                        .frame(height: 170)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    VStack(spacing: 4) {
                        Text(item.exercise.name).font(.title3.bold()).multilineTextAlignment(.center)
                        Text(item.isRepTest ? "Last set: as many good reps as you can" : LiftFormat.reserve(item.repsInReserve))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    setList
                    exercisePicker
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            if let restEnds {
                RestBanner(ends: restEnds) { self.restEnds = nil } onAdjust: { self.restEnds = restEnds.addingTimeInterval($0) }
            }
        }
    }

    private var setList: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Set").frame(width: 32)
                Text(session.unit).frame(maxWidth: .infinity)
                Text("Reps").frame(maxWidth: .infinity)
                Text("Done").frame(width: 48)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            ForEach(Array((entries[item.id] ?? []).enumerated()), id: \.element.id) { index, entry in
                row(index: index, entry: entry)
            }
            Button {
                let last = entries[item.id]?.last
                entries[item.id, default: []].append(SetEntry(weight: last?.weight ?? 0, reps: last?.reps ?? item.reps))
            } label: {
                Label("Add Set", systemImage: "plus").font(.subheadline)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private func row(index: Int, entry: SetEntry) -> some View {
        let binding = Binding(
            get: { entries[item.id]?[index] ?? entry },
            set: { entries[item.id]?[index] = $0 }
        )
        return HStack {
            Text("\(index + 1)").font(.numeral(16, weight: .semibold)).frame(width: 32)
            if item.exercise.isBodyweight {
                Text("BW").foregroundStyle(.secondary).frame(maxWidth: .infinity)
            } else {
                TextField("0", value: binding.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.numeral(18, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Weight for set \(index + 1)")
            }
            TextField("0", value: binding.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.numeral(18, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Reps for set \(index + 1)")
            Button {
                complete(index)
            } label: {
                Image(systemName: entry.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(entry.isDone ? Theme.brand : Color.secondary)
                    .frame(width: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Finish set \(index + 1)")
        }
    }

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today's exercises").font(.subheadline.weight(.semibold))
            ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                Button {
                    current = index
                } label: {
                    HStack {
                        let sets = entries[exercise.id] ?? []
                        let isDone = !sets.isEmpty && sets.allSatisfy(\.isDone)
                        Image(systemName: isDone ? "checkmark.circle.fill" : index == current ? "dot.circle.fill" : "circle")
                            .foregroundStyle(isDone || index == current ? Theme.brand : Color.secondary)
                        Text(exercise.exercise.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text(LiftFormat.prescription(exercise, unit: session.unit)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private func complete(_ index: Int) {
        guard let isDone = entries[item.id]?[index].isDone else { return }
        entries[item.id]?[index].isDone = !isDone
        guard !isDone else { return }
        restEnds = Date().addingTimeInterval(Double(item.restSeconds))
        if entries[item.id]?.allSatisfy(\.isDone) == true, current + 1 < session.exercises.count {
            current += 1
        }
    }

    private func finish() {
        if session.isSelfPaced {
            entries = SelfPacedLog.entries(for: session.exercises, testReps: testReps)
        }
        let log = WorkoutLog(date: Date(), title: session.title, week: session.week, dayIndex: session.dayIndex, minutes: Int(Date().timeIntervalSince(started) / 60))
        context.insert(log)
        for planned in session.exercises {
            for (index, entry) in (entries[planned.id] ?? []).enumerated() where entry.isDone {
                let set = SetLog(exerciseID: planned.exercise.id, setNumber: index + 1, weight: entry.weight, reps: entry.reps)
                context.insert(set)
                set.workout = log
            }
        }
        var byExercise: [String: [SetEntry]] = [:]
        for planned in session.exercises where !planned.exercise.isBodyweight {
            // Self-paced sets are only the plan, so they say nothing about your strength unless you tested.
            if session.isSelfPaced, testReps[planned.id] == nil { continue }
            byExercise[planned.exercise.id, default: []] += entries[planned.id] ?? []
        }
        // Compared with your working numbers, estimates included: a planned set left reps in reserve, so on its own
        // it says little about your max, and must only ever raise it.
        var known = Dictionary(maxes.map { ($0.exerciseID, $0.oneRepMax) }, uniquingKeysWith: max)
        if let profile = plans.first?.profile(maxes: maxes) {
            for planned in session.exercises where known[planned.exercise.id] == nil {
                known[planned.exercise.id] = profile.oneRepMax(for: planned.exercise)
            }
        }
        let tests = Set(session.exercises.filter { $0.isRepTest && (!session.isSelfPaced || testReps[$0.id] != nil) }.map(\.exercise.id))
        let records = LiftRecords.records(from: byExercise, known: known, repTests: tests)
        for record in records {
            if let existing = maxes.first(where: { $0.exerciseID == record.exerciseID }) {
                existing.oneRepMax = record.oneRepMax
                existing.updated = Date()
            } else {
                context.insert(LiftMax(exerciseID: record.exerciseID, oneRepMax: record.oneRepMax))
            }
        }
        try? context.save()
        withAnimation { finishedRecords = records.filter { $0.previous != nil && $0.oneRepMax > ($0.previous ?? 0) } }
    }

    private func summary(_ records: [LiftRecords.Record]) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(Theme.brand)
            Text("Nice work").font(.title.bold())
            Text(session.isSelfPaced ? "\(doneSets) sets logged" : "\(doneSets) sets in \(max(Int(Date().timeIntervalSince(started) / 60), 1)) min")
                .foregroundStyle(.secondary)
            if !records.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("New records", systemImage: "trophy.fill").font(.headline).foregroundStyle(Theme.brand)
                    ForEach(records) { record in
                        HStack {
                            Text(ExerciseCatalog.exercise(record.exerciseID)?.name ?? "").font(.subheadline)
                            Spacer()
                            Text("\(LiftFormat.weight(record.oneRepMax.rounded(), unit: session.unit)) 1RM").font(.numeral(15, weight: .semibold))
                        }
                    }
                }
                .padding()
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Done").font(.headline).foregroundStyle(Theme.onBrand).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 14))
        }
        .padding()
    }
}

private struct RestBanner: View {
    let ends: Date
    let onSkip: () -> Void
    let onAdjust: (TimeInterval) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let left = max(Int(ends.timeIntervalSince(timeline.date).rounded(.up)), 0)
            HStack {
                Image(systemName: "timer").foregroundStyle(Theme.brand)
                Text(left == 0 ? "Rest done" : "Rest \(left / 60):\(String(format: "%02d", left % 60))")
                    .font(.numeral(18, weight: .semibold))
                    .monospacedDigit()
                Spacer()
                Button("-15") { onAdjust(-15) }.buttonStyle(.bordered)
                Button("+15") { onAdjust(15) }.buttonStyle(.bordered)
                Button("Skip", action: onSkip).buttonStyle(.bordered)
            }
            .controlSize(.small)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .sensoryFeedback(.impact, trigger: left == 0)
        }
    }
}
