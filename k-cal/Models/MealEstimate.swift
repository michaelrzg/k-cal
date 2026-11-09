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
    /// A name of its own, where the label doesn't make one.
    var title: String? = nil

    var id: String { label }

    var name: String {
        title ?? label.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct MealEstimate: Equatable {
    /// Portions to offer, as a share of what the photo model saw.
    static let portions: [Double] = [0.5, 0.75, 1, 1.25, 1.5, 2]
    /// Below this the name comes from the ingredients, which describe a mixed plate better than any one of 101 dishes.
    static let minimumNameConfidence = 0.6
    /// Below this an ingredient isn't worth putting in a meal's name.
    static let minimumIngredientChance = 0.9
    /// Below this a guess isn't worth offering at all.
    static let minimumSuggestionConfidence = 0.1
    static let fallbackName = "Photo meal"

    var calories: Double
    var carbohydrates: Double
    var protein: Double
    var fat: Double
    /// The weight, known only once the meal is matched to a food. A photo gives calories, not grams.
    var grams: Double?
    /// Best first.
    var dishes: [DishGuess]
    /// What the plate model thinks is on the plate, likeliest first. For naming the meal, not for adding up.
    var ingredients: [String] = []

    /// - Parameter logTotals: the plate model's output, log1p of kcal, carbs, protein, fat.
    init?(logTotals: [Double], dishes: [DishGuess]) {
        guard logTotals.count == 4, logTotals.allSatisfy(\.isFinite) else { return nil }
        // Negative logs mean zero, and e^9 is 8,000 kcal, more than any plate.
        let totals = logTotals.map { expm1(min(max($0, 0), 9)) }
        calories = totals[0]
        carbohydrates = totals[1]
        protein = totals[2]
        fat = totals[3]
        self.dishes = dishes
        guard calories > 0 else { return nil }
    }

    var suggestedName: String {
        if let best = dishes.first, best.confidence >= Self.minimumNameConfidence { return best.name }
        return PhotoFoodNamer.title(from: ingredients) ?? Self.fallbackName
    }

    /// Picks the likeliest ingredients out of the plate model's output.
    /// - Parameters:
    ///   - chances: the chance of each ingredient, in the order of `names`.
    static func likelyIngredients(_ chances: [Double], names: [String]) -> [String] {
        var seen = Set<String>()
        return zip(chances, names).filter { $0.0 >= minimumIngredientChance }.sorted { $0.0 > $1.0 }.map(\.1)
            .filter { seen.insert($0.hasSuffix("s") ? String($0.dropLast()) : $0).inserted }
    }

    var suggestions: [DishGuess] {
        dishes.filter { $0.confidence >= Self.minimumSuggestionConfidence }
    }

    /// The same meal in a bigger or smaller portion.
    func scaled(by portion: Double) -> MealEstimate {
        var copy = self
        copy.grams = grams.map { $0 * portion }
        copy.calories *= portion
        copy.fat *= portion
        copy.carbohydrates *= portion
        copy.protein *= portion
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
            ingredients: estimate.grams.map { "Estimated from a photo, about \(Int($0.rounded())) g." } ?? "Estimated from a photo.",
            url: nil,
            barcode: nil,
            brand: "Photo estimate"
        )
    }
}
