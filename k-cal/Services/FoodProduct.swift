//
//  FoodProduct.swift
//  k-cal
//
//  One food from any source, normalised to a single serving.
//

import Foundation

struct Nutrition: Equatable, Sendable {
    var calories: Double
    var protein: Double = 0
    var carbohydrates: Double = 0
    var fat: Double = 0
    var sodiumMilligrams: Double = 0
    var sugars: Double = 0
    var fiber: Double = 0

    func scaled(by factor: Double) -> Nutrition {
        Nutrition(
            calories: calories * factor,
            protein: protein * factor,
            carbohydrates: carbohydrates * factor,
            fat: fat * factor,
            sodiumMilligrams: sodiumMilligrams * factor,
            sugars: sugars * factor,
            fiber: fiber * factor
        )
    }
}

struct FoodProduct: Identifiable, Equatable, Sendable {
    enum Source: String, Sendable {
        case custom = "My Foods"
        case usda = "USDA"
        case openFoodFacts = "Open Food Facts"
        case canadianNutrientFile = "Health Canada"
    }

    let id: String
    var name: String
    var brand: String?
    var barcode: String?
    var imageURL: URL?
    /// What one serving is, e.g. "2 Tbsp (30 g)".
    var serving: String
    var ingredients: String?
    var nutrition: Nutrition
    var source: Source
}

extension Food {
    /// An unsaved Food for AddFoodSheet to review.
    convenience init(product: FoodProduct, day: Day, meal: Meal) {
        self.init(
            name: product.name,
            day: day,
            protein: Int(product.nutrition.protein.rounded()),
            carbohydrates: Int(product.nutrition.carbohydrates.rounded()),
            fat: Int(product.nutrition.fat.rounded()),
            meal: meal,
            servings: 1,
            calories_per_serving: Int(product.nutrition.calories.rounded()),
            sodium: Int(product.nutrition.sodiumMilligrams.rounded()),
            sugars: Int(product.nutrition.sugars.rounded()),
            fiber: Int(product.nutrition.fiber.rounded()),
            ingredients: product.ingredients,
            url: product.imageURL?.absoluteString,
            barcode: product.barcode,
            brand: product.brand
        )
        serving = product.serving
    }

    /// An unsaved copy of a logged food, one serving, for logging it again.
    convenience init(copying other: Food, day: Day, meal: Meal) {
        let servings = max(other.servings, 1)
        self.init(
            name: other.name,
            day: day,
            protein: other.protein / servings,
            carbohydrates: other.carbohydrates / servings,
            fat: other.fat / servings,
            meal: meal,
            servings: 1,
            calories_per_serving: other.calories_per_serving,
            sodium: other.sodium,
            sugars: other.sugars,
            fiber: other.fiber,
            ingredients: other.ingredients,
            url: other.url,
            barcode: other.barcode,
            brand: other.brand
        )
        serving = other.serving
    }
}
