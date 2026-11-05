//
//  CustomFoodEditor.swift
//  k-cal
//
//  Create or edit a custom food.
//

import SwiftData
import SwiftUI

struct CustomFoodEditor: View {
    /// The food being edited, or nil to create one.
    let food: CustomFood?
    let onSave: (CustomFood) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name: String
    @State private var brand: String
    @State private var serving: String
    @State private var barcode: String
    @State private var calories: Int?
    @State private var protein: Int?
    @State private var carbohydrates: Int?
    @State private var fat: Int?
    @State private var sodium: Int?
    @State private var sugars: Int?
    @State private var fiber: Int?

    init(food: CustomFood? = nil, barcode: String = "", onSave: @escaping (CustomFood) -> Void = { _ in }) {
        self.food = food
        self.onSave = onSave
        _name = State(initialValue: food?.name ?? "")
        _brand = State(initialValue: food?.brand ?? "")
        _serving = State(initialValue: food?.serving ?? "")
        _barcode = State(initialValue: food?.barcode ?? barcode)
        _calories = State(initialValue: food?.calories)
        _protein = State(initialValue: food?.protein)
        _carbohydrates = State(initialValue: food?.carbohydrates)
        _fat = State(initialValue: food?.fat)
        _sodium = State(initialValue: food?.sodium)
        _sugars = State(initialValue: food?.sugars)
        _fiber = State(initialValue: food?.fiber)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && calories != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Serving, e.g. 1 cup (240 ml)", text: $serving)
                    TextField("Barcode (optional)", text: $barcode)
                        .keyboardType(.numberPad)
                }
                Section("Per serving") {
                    amount("Calories", $calories, unit: "kcal")
                    amount("Protein", $protein, unit: "g")
                    amount("Carbs", $carbohydrates, unit: "g")
                    amount("Fat", $fat, unit: "g")
                    amount("Sodium", $sodium, unit: "mg")
                    amount("Sugar", $sugars, unit: "g")
                    amount("Fiber", $fiber, unit: "g")
                }
            }
            .navigationTitle(food == nil ? "New Food" : "Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func amount(_ title: String, _ value: Binding<Int?>, unit: String) -> some View {
        HStack {
            Text(title)
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func save() {
        guard let calories else { return }
        let saved = food ?? CustomFood(name: trimmedName, calories: calories)
        saved.name = trimmedName
        saved.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.serving = serving.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.barcode = barcode.filter(\.isNumber)
        saved.calories = calories
        saved.protein = protein ?? 0
        saved.carbohydrates = carbohydrates ?? 0
        saved.fat = fat ?? 0
        saved.sodium = sodium ?? 0
        saved.sugars = sugars ?? 0
        saved.fiber = fiber ?? 0
        if food == nil {
            context.insert(saved)
        }
        onSave(saved)
        dismiss()
    }
}
