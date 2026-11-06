//
//  FoodEntrySheet.swift
//  k-cal
//
//  Reviews a new food before logging it, and edits one already logged.
//

import SwiftData
import SwiftUI

struct FoodEntrySheet: View {
    enum Mode {
        case add(date: Date)
        case edit
    }

    private static let meals = ["Breakfast", "Lunch", "Dinner", "Snack"]

    @Bindable var food: Food
    let mode: Mode
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var date: Date
    @State private var calories: Int
    @State private var protein: Int
    @State private var carbohydrates: Int
    @State private var fat: Int

    private var isAdding: Bool {
        if case .add = mode { return true }
        return false
    }

    init(food: Food, mode: Mode, onSaved: @escaping () -> Void = {}) {
        self.food = food
        self.mode = mode
        self.onSaved = onSaved
        let servings = max(food.servings, 1)
        switch mode {
        case let .add(date): _date = State(initialValue: date)
        case .edit: _date = State(initialValue: food.day?.date ?? Date())
        }
        _calories = State(initialValue: food.calories_per_serving)
        _protein = State(initialValue: food.protein / servings)
        _carbohydrates = State(initialValue: food.carbohydrates / servings)
        _fat = State(initialValue: food.fat / servings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    summary
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Group {
                Section {
                    TextField("Name", text: $food.name)
                    if let brand = food.brand, !brand.isEmpty {
                        LabeledContent("Brand", value: brand)
                    }
                    Picker("Meal", selection: $food.meal) {
                        ForEach(Self.meals, id: \.self) { Text($0) }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Stepper(value: $food.servings, in: 1 ... 100) {
                        LabeledContent("Servings", value: "\(food.servings)")
                    }
                    if !food.serving.isEmpty {
                        LabeledContent("Serving", value: food.serving)
                    }
                }
                Section("Per serving") {
                    amountRow("Calories", value: $calories, unit: "cal")
                    amountRow("Protein", value: $protein, unit: "g", color: Theme.protein)
                    amountRow("Carbs", value: $carbohydrates, unit: "g", color: Theme.carbohydrate)
                    amountRow("Fat", value: $fat, unit: "g", color: Theme.fat)
                }
                if food.sodium > 0 || food.sugars > 0 || food.fiber > 0 {
                    Section("Also in this food") {
                        if food.sodium > 0 { LabeledContent("Sodium", value: "\(food.sodium * food.servings) mg") }
                        if food.sugars > 0 { LabeledContent("Sugar", value: "\(food.sugars * food.servings) g") }
                        if food.fiber > 0 { LabeledContent("Fiber", value: "\(food.fiber * food.servings) g") }
                    }
                }
                if !food.ingredients.isEmpty {
                    Section {
                        DisclosureGroup("Ingredients") {
                            Text(food.ingredients).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                }
                .listRowBackground(Theme.card)
                InlineAd(unitID: isAdding ? AddFoodSheetBottomBannerId : UpdateFoodSheetBottomBannerId)
            }
            .themedList()
            .navigationTitle(isAdding ? "Add Food" : "Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isAdding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isAdding ? "Log" : "Done", action: save).bold()
                }
            }
            .onChange(of: food.servings) { applyAmounts() }
            .onChange(of: calories) { applyAmounts() }
            .onChange(of: protein) { applyAmounts() }
            .onChange(of: carbohydrates) { applyAmounts() }
            .onChange(of: fat) { applyAmounts() }
        }
        .presentationDragIndicator(.visible)
    }

    private var summary: some View {
        VStack(spacing: 14) {
            if let url = URL(string: food.url) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            VStack(spacing: 0) {
                Text(food.calories.formatted())
                    .font(.numeral(44))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("calories").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                macro("Protein", food.protein, Theme.protein)
                macro("Carbs", food.carbohydrates, Theme.carbohydrate)
                macro("Fat", food.fat, Theme.fat)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func macro(_ name: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value) g").font(.numeral(17, weight: .semibold)).monospacedDigit()
            Text(name).font(.caption).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func amountRow(_ title: String, value: Binding<Int>, unit: String, color: Color = .primary) -> some View {
        HStack {
            Text(title).foregroundStyle(color)
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary).frame(width: 24, alignment: .leading)
        }
    }

    private func applyAmounts() {
        food.calories_per_serving = calories
        food.calories = calories * food.servings
        food.protein = protein * food.servings
        food.carbohydrates = carbohydrates * food.servings
        food.fat = fat * food.servings
    }

    private func save() {
        applyAmounts()
        if isAdding {
            context.insert(food)
            context.insert(Search(food: food, day: Date()))
        }
        // Refiling moves this food alone. Editing the Day's own date would move everything logged on it.
        if !isAdding, let current = food.day?.date, Calendar.current.isDate(current, inSameDayAs: date) {
            // Already on the right day.
        } else if let day = try? Day.find(date, in: context) {
            food.day = day
        }
        try? context.save()
        onSaved()
        dismiss()
    }
}
