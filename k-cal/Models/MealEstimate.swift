//
//  MealEstimate.swift
//  k-cal
//
//  What the meal-photo models say about a plate, before it becomes a Food.
//

import Foundation

struct DishGuess: Equatable, Identifiable {
    /// A Food-101 class name such as "spaghetti_bolognese".
    let label: String
    let confidence: Double

    var id: String { label }

    var name: String {
        label.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct MealEstimate: Equatable {
    /// Weights outside this range are not meaningful for a photographed meal.
    static let gramsRange = 10.0 ... 3000.0
    /// Below this the dish classifier is usually wrong, so it isn't offered as the name.
    static let minimumNameConfidence = 0.35
    /// Below this a guess isn't worth offering at all.
    static let minimumSuggestionConfidence = 0.1
    static let fallbackName = "Photo meal"

    var grams: Double
    var calories: Double
    var fat: Double
    var carbohydrates: Double
    var protein: Double
    /// Best first.
    var dishes: [DishGuess]

    /// - Parameter logTotals: the portion model's output, log1p of kcal, grams, fat, carbs, protein.
    init?(logTotals: [Double], dishes: [DishGuess]) {
        guard logTotals.count == 5, logTotals.allSatisfy(\.isFinite) else { return nil }
        // Same clamp as upstream: negative logs mean zero, e^8 is about 3 kg.
        let totals = logTotals.map { expm1(min(max($0, 0), 8)) }
        calories = totals[0]
        grams = totals[1]
        fat = totals[2]
        carbohydrates = totals[3]
        protein = totals[4]
        self.dishes = dishes
        guard grams > 0 else { return nil }
    }

    var suggestedName: String {
        guard let best = dishes.first, best.confidence >= Self.minimumNameConfidence else {
            return Self.fallbackName
        }
        return best.name
    }

    var suggestions: [DishGuess] {
        dishes.filter { $0.confidence >= Self.minimumSuggestionConfidence }
    }

    /// The same meal at a different weight. Energy and macros scale with it.
    func scaled(toGrams newGrams: Double) -> MealEstimate {
        var copy = self
        let ratio = newGrams / grams
        copy.grams = newGrams
        copy.calories *= ratio
        copy.fat *= ratio
        copy.carbohydrates *= ratio
        copy.protein *= ratio
        return copy
    }
}

extension Meal {
    /// The meal someone is most likely logging at this hour of the day.
    init(hour: Int) {
        switch hour {
        case 4 ..< 11: self = .breakfast
        case 11 ..< 15: self = .lunch
        case 17 ..< 22: self = .dinner
        default: self = .snack
        }
    }
}

extension Food {
    /// An unsaved Food for AddFoodSheet to review.
    convenience init(estimate: MealEstimate, name: String, day: Day, meal: Meal) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            name: trimmed.isEmpty ? MealEstimate.fallbackName : trimmed,
            day: day,
            protein: Int(estimate.protein.rounded()),
            carbohydrates: Int(estimate.carbohydrates.rounded()),
            fat: Int(estimate.fat.rounded()),
            meal: meal,
            servings: 1,
            calories_per_serving: Int(estimate.calories.rounded()),
            sodium: nil,
            sugars: nil,
            fiber: nil,
            ingredients: "Estimated from a photo, about \(Int(estimate.grams.rounded())) g.",
            url: nil,
            barcode: nil,
            brand: "Photo estimate"
        )
    }
}
