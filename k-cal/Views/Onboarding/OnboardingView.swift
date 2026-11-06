//
//  OnboardingView.swift
//  k-cal
//
//  First launch: what k-cal is, who you are, and your goals.
//

import SwiftData
import SwiftUI

struct OnboardingView: View {
    private enum Step: Int, CaseIterable {
        case welcome
        case features
        case name
        case goals
    }

    @Environment(\.modelContext) private var context
    @State private var step = Step.welcome
    @State private var name = ""
    @State private var activity = ActivityLevel.lightlyActive
    @State private var calories = ActivityLevel.lightlyActive.suggestedCalories
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var macros: (protein: Int, carbohydrates: Int, fat: Int) {
        activity.macros(forCalories: calories)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .features: features
                case .name: nameEntry
                case .goals: goals
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))

            Button(action: advance) {
                Text(step == .goals ? "Get Started" : "Continue")
                    .font(.headline)
                    .foregroundStyle(Theme.onBrand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .disabled(step == .name && trimmedName.isEmpty)
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var welcome: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Theme.brand)
            Text("k-cal").font(.numeral(44))
            Text("Calorie tracking without the fuss.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            HStack(spacing: 18) {
                Label("Free", systemImage: "checkmark")
                Label("No tracking", systemImage: "checkmark")
                Label("No subscriptions", systemImage: "checkmark")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding()
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            Text("Log food in seconds").font(.largeTitle.bold())
            feature("barcode.viewfinder", "Scan a barcode", "Over a million foods on your phone, online or not.")
            feature("camera", "Snap your meal", "Estimate calories from a photo that stays on your phone.")
            feature("chart.pie", "See your day", "Calories and macros at a glance, right on your Home Screen.")
            Spacer()
        }
        .padding(24)
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Theme.brand)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var nameEntry: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("What should we call you?").font(.largeTitle.bold())
            TextField("Your name", text: $name)
                .font(.title3)
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .focused($isNameFocused)
                .textContentType(.givenName)
                .submitLabel(.next)
                .onSubmit(advance)
            Spacer()
            Spacer()
        }
        .padding(24)
        .onAppear { isNameFocused = true }
    }

    private var goals: some View {
        Form {
            Section {
                Text("Set your daily goals").font(.largeTitle.bold())
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            Group {
            Section("Activity") {
                Picker("Activity", selection: $activity) {
                    ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Section {
                Stepper(value: $calories, in: 1200 ... 6000, step: 50) {
                    LabeledContent("Calories", value: calories.formatted())
                }
                LabeledContent("Protein", value: "\(macros.protein) g")
                LabeledContent("Carbs", value: "\(macros.carbohydrates) g")
                LabeledContent("Fat", value: "\(macros.fat) g")
            } header: {
                Text("Daily goal")
            } footer: {
                Text("You can change these any time in your profile.")
            }
            }
            .listRowBackground(Theme.card)
        }
        .themedList()
        .onChange(of: activity) { calories = activity.suggestedCalories }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            guard step != .name || !trimmedName.isEmpty else { return }
            isNameFocused = false
            withAnimation(.snappy) { step = next }
        } else {
            let plan = macros
            context.insert(User(name: trimmedName, calorie_goal: calories, protein_goal: plan.protein, carb_goal: plan.carbohydrates, fat_goal: plan.fat))
            try? context.save()
        }
    }
}
