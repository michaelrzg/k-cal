//
//  DayLog.swift
//  k-cal
//
//  One day's meals as list sections, shared by Today and the Diary.
//

import SwiftData
import SwiftUI

extension Food {
    /// True when this food is filed under the same day as `date`.
    func isLogged(on date: Date, calendar: Calendar = .current) -> Bool {
        day.map { calendar.isDate($0.date, inSameDayAs: date) } ?? false
    }
}

extension Day {
    /// The day for `date`, created if nothing has been logged on it yet.
    static func find(_ date: Date, in context: ModelContext, calendar: Calendar = .current) throws -> Day {
        let start = calendar.startOfDay(for: date)
        let descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.date == start })
        if let existing = try context.fetch(descriptor).first { return existing }
        let created = Day(date: start)
        context.insert(created)
        return created
    }
}

struct DayLog: View {
    private static let meals: [(title: String, meal: Meal, symbol: String)] = [
        ("Breakfast", .breakfast, "sunrise"),
        ("Lunch", .lunch, "sun.max"),
        ("Dinner", .dinner, "moon.stars"),
        ("Snack", .snack, "carrot"),
    ]

    let foods: [Food]
    let date: Date

    @Environment(AddFoodFlow.self) private var flow
    @State private var editing: Food?

    var body: some View {
        ForEach(Self.meals, id: \.title) { entry in
            let logged = foods.filter { $0.meal == entry.title }
            Section {
                ForEach(logged) { food in
                    Button { editing = food } label: { FoodLogRow(food: food) }
                        .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    // Unfiled rather than deleted, because recent foods still refer to it.
                    offsets.forEach { logged[$0].day = nil }
                }
                addMenu(for: entry.meal, title: entry.title)
            } header: {
                HStack {
                    Label(entry.title, systemImage: entry.symbol)
                    Spacer()
                    if !logged.isEmpty {
                        Text("\(logged.reduce(0) { $0 + $1.calories }.formatted()) cal").monospacedDigit()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
            }
            .listRowBackground(Theme.card)
        }
        .sheet(item: $editing) { food in
            FoodEntrySheet(food: food, mode: .edit)
        }
    }

    private func addMenu(for meal: Meal, title: String) -> some View {
        Menu {
            Button { flow.start(.scan, meal: meal, date: date) } label: { Label("Scan Barcode", systemImage: "barcode.viewfinder") }
            Button { flow.start(.snapMeal, meal: meal, date: date) } label: { Label("Snap a Photo", systemImage: "camera") }
            Button { flow.startSearch(meal: meal, date: date) } label: { Label("Search", systemImage: "magnifyingglass") }
            Button { flow.start(.myFoods, meal: meal, date: date) } label: { Label("My Foods", systemImage: "square.and.pencil") }
        } label: {
            Label("Add Food", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.brand)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Add to \(title)")
    }
}

struct FoodLogRow: View {
    let food: Food

    private var detail: String {
        [food.brand ?? "", food.servings > 1 ? "\(food.servings) servings" : food.serving]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).font(.body).lineLimit(2)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(food.calories.formatted()).font(.numeral(17, weight: .semibold)).monospacedDigit()
                Text("\(food.protein)p \(food.carbohydrates)c \(food.fat)f")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}
