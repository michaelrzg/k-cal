//
//  LiftSetupView.swift
//  k-cal
//
//  Builds a program from your goal, schedule and numbers, and recommends a split.
//

import SwiftData
import SwiftUI

struct LiftSetupView: View {
    private enum Step: Int, CaseIterable {
        case goal
        case schedule
        case strength
        case style
        case split
    }

    private static let weekdayNames = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")]

    let existing: LiftPlan?
    /// Begin again at week 1, rather than change the plan you're on.
    var startsOver = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var maxes: [LiftMax]
    @State private var step = Step.goal
    @State private var goal = LiftGoal.muscle
    @State private var experience = LiftExperience.intermediate
    @State private var weekdays = Set(WorkoutPlanner.suggestedWeekdays(daysPerWeek: 4))
    @State private var usesPounds = Locale.current.measurementSystem != .metric
    @State private var bodyweight: Double?
    @State private var focus: Muscle?
    @State private var entered: [AnchorLift: Double] = [:]
    @State private var splitID: String?
    @State private var isSelfPaced = false
    @State private var matchesNutrition = true

    private var recommended: TrainingSplit {
        SplitLibrary.recommended(daysPerWeek: weekdays.count, experience: experience, goal: goal)
    }

    private var chosen: TrainingSplit {
        splitID.flatMap(SplitLibrary.split(id:)) ?? recommended
    }

    private var canContinue: Bool {
        switch step {
        case .schedule: weekdays.count >= 2
        case .strength: (bodyweight ?? 0) > 0
        default: true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .goal: goalStep
                case .schedule: scheduleStep
                case .strength: strengthStep
                case .style: styleStep
                case .split: splitStep
                }
            }
            .themedList()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .goal ? "Cancel" : "Back") {
                        if let previous = Step(rawValue: step.rawValue - 1) { step = previous } else { dismiss() }
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: advance) {
                    Text(step == .split ? "Start Program" : "Continue")
                        .font(.headline)
                        .foregroundStyle(Theme.onBrand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .disabled(!canContinue)
                .padding()
                .background(Theme.background.ignoresSafeArea())
            }
        }
        .onAppear(perform: loadExisting)
    }

    private var title: String {
        switch step {
        case .goal: "Your Goal"
        case .schedule: "Your Week"
        case .strength: "Your Strength"
        case .style: "Your Style"
        case .split: "Your Split"
        }
    }

    @ViewBuilder
    private var goalStep: some View {
        Section("What are you training for?") {
            ForEach(LiftGoal.allCases) { option in
                choice(option.rawValue, detail: option.detail, isOn: goal == option) { goal = option }
            }
        }
        .listRowBackground(Theme.card)
        Section("How long have you been lifting?") {
            ForEach(LiftExperience.allCases) { option in
                choice(option.rawValue, detail: option.detail, isOn: experience == option) { experience = option }
            }
        }
        .listRowBackground(Theme.card)
    }

    @ViewBuilder
    private var scheduleStep: some View {
        Section {
            HStack(spacing: 6) {
                ForEach(Self.weekdayNames, id: \.0) { day, letter in
                    Button {
                        if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
                        splitID = nil
                    } label: {
                        Text(letter)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(weekdays.contains(day) ? Theme.onBrand : .primary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(weekdays.contains(day) ? Theme.brand : Color(.tertiarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                }
            }
        } header: {
            Text("Which days can you train?")
        } footer: {
            Text("\(weekdays.count) days a week. If you miss one, the program waits for you.")
        }
        .listRowBackground(Theme.card)
        Section("Bring up a weak point? (optional)") {
            Picker("Extra sets for", selection: $focus) {
                Text("Balanced").tag(Muscle?.none)
                ForEach(Muscle.allCases) { Text($0.rawValue).tag(Muscle?.some($0)) }
            }
        }
        .listRowBackground(Theme.card)
    }

    @ViewBuilder
    private var strengthStep: some View {
        Section {
            Picker("Units", selection: $usesPounds) {
                Text("Pounds").tag(true)
                Text("Kilograms").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            amountRow("Bodyweight", value: $bodyweight, placeholder: "Required")
        }
        .listRowBackground(Theme.card)
        Section {
            ForEach(AnchorLift.allCases) { lift in
                amountRow(lift.title, value: Binding(get: { entered[lift] }, set: { entered[lift] = $0 }), placeholder: placeholder(for: lift))
            }
        } header: {
            Text("One-rep maxes (optional)")
        } footer: {
            Text("Leave any blank and we'll estimate it from your bodyweight and experience. Your rep tests will correct it as you go.")
        }
        .listRowBackground(Theme.card)
    }

    private func placeholder(for lift: AnchorLift) -> String {
        guard let bodyweight, bodyweight > 0 else { return "Estimate" }
        return "~\(Int((bodyweight * lift.bodyweightRatio(for: experience) / 5).rounded() * 5))"
    }

    private func amountRow(_ title: String, value: Binding<Double?>, placeholder: String) -> some View {
        HStack {
            Text(title)
            TextField(placeholder, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(usesPounds ? "lb" : "kg").foregroundStyle(.secondary).frame(width: 22)
        }
    }

    private var nutrition: NutritionPlan {
        NutritionPlan(bodyweight: bodyweight ?? 0, usesPounds: usesPounds, goal: goal, trainingDays: weekdays.count)
    }

    @ViewBuilder
    private var styleStep: some View {
        Section("During a workout") {
            choice("Guided", detail: "Tick off each set, adjust the weight and reps, and rest with a timer.", isOn: !isSelfPaced) { isSelfPaced = false }
            choice("Self-Paced", detail: "Just see your sets. No timer and nothing to tick, and it logs as planned when you finish.", isOn: isSelfPaced) { isSelfPaced = true }
        }
        .listRowBackground(Theme.card)
        Section {
            Toggle("Match food goals to training", isOn: $matchesNutrition).tint(Theme.brand)
            if matchesNutrition {
                LabeledContent("Training days", value: "\(nutrition.training.calories.formatted()) cal")
                LabeledContent("Rest days", value: "\(nutrition.rest.calories.formatted()) cal")
                LabeledContent("Protein", value: "\(nutrition.training.protein) g a day")
            }
        } header: {
            Text("Food")
        } footer: {
            Text("An estimate from your bodyweight, goal and training days. It can't see your height or age, so adjust if your weight isn't moving as you'd like. Your Profile goals are kept, and turning this off brings them back.")
        }
        .listRowBackground(Theme.card)
    }

    @ViewBuilder
    private var splitStep: some View {
        Section {
            ForEach(SplitLibrary.options(daysPerWeek: weekdays.count)) { split in
                Button {
                    splitID = split.id
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(split.name).font(.headline).foregroundStyle(.primary)
                            if split.id == recommended.id {
                                Text("Recommended")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.brand)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Theme.brand.opacity(0.14), in: Capsule())
                            }
                            Spacer()
                            if split.id == chosen.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.brand)
                            }
                        }
                        Text("\(split.daysPerWeek) days a week").font(.caption).foregroundStyle(.secondary)
                        Text(split.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("Based on training \(weekdays.count) days a week as \(experience.rawValue.lowercased()) lifter.")
        }
        .listRowBackground(Theme.card)
        Section("Your week") {
            ForEach(Array(chosen.days.enumerated()), id: \.offset) { index, day in
                LabeledContent(day.name, value: weekdayLabel(index))
            }
        }
        .listRowBackground(Theme.card)
    }

    private func weekdayLabel(_ index: Int) -> String {
        let order = [2, 3, 4, 5, 6, 7, 1].filter(weekdays.contains)
        guard !order.isEmpty else { return "" }
        return Calendar.current.shortWeekdaySymbols[order[index % order.count] - 1]
    }

    private func choice(_ title: String, detail: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if isOn { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.brand) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        } else {
            save()
        }
    }

    private func loadExisting() {
        guard let existing else { return }
        goal = existing.goal
        experience = existing.experience
        weekdays = Set(existing.weekdays)
        usesPounds = existing.usesPounds
        bodyweight = existing.bodyweight
        focus = existing.focus
        splitID = existing.splitID
        isSelfPaced = existing.isSelfPaced
        matchesNutrition = existing.matchesNutrition
        for lift in AnchorLift.allCases {
            entered[lift] = maxes.first { $0.exerciseID == lift.exerciseID }?.oneRepMax
        }
    }

    private func save() {
        guard let bodyweight else { return }
        // Changing settings keeps your place. Only a different split, or asking to, goes back to week 1.
        let keepsProgress = existing?.splitID == chosen.id && !startsOver
        let started = keepsProgress ? existing?.started : nil
        if let existing { context.delete(existing) }
        context.insert(LiftPlan(goal: goal, experience: experience, splitID: chosen.id, weekdays: weekdays.sorted(), bodyweight: bodyweight, usesPounds: usesPounds, focus: focus, started: started ?? Date(), isSelfPaced: isSelfPaced, matchesNutrition: matchesNutrition))
        for (lift, value) in entered where value > 0 {
            if let known = maxes.first(where: { $0.exerciseID == lift.exerciseID }) {
                known.oneRepMax = value
                known.updated = Date()
            } else {
                context.insert(LiftMax(exerciseID: lift.exerciseID, oneRepMax: value))
            }
        }
        try? context.save()
        dismiss()
    }
}
