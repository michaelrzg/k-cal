//
//  MealMatching.swift
//  k-cal
//
//  Gives a recognised dish its real macros, using a hand-checked table linking each dish to a database food
//  (tools/food_database/dishes.py).
//

import Foundation

/// A database food for a dish, usable by weight.
struct DishMatch: Equatable, Identifiable, Sendable {
    let dish: DishGuess
    let food: FoodProduct
    /// The weight of one, for a food that comes in pieces. The numbers then come from the food alone.
    var itemGrams: Double? = nil

    var id: String { dish.id }
}

extension FoodProduct {
    /// Nutrition for one gram, where the serving's weight is known.
    var nutritionPerGram: Nutrition? {
        guard let servingGrams, servingGrams > 0 else { return nil }
        return nutrition.scaled(by: 1 / servingGrams)
    }
}

extension MealEstimate {
    func matched(to match: DishMatch) -> MealEstimate? {
        guard let itemGrams = match.itemGrams else { return matched(to: match.food) }
        guard let amount = match.food.nutritionPerGram?.scaled(by: itemGrams) else { return nil }
        var copy = self
        copy.grams = itemGrams
        copy.calories = amount.calories
        copy.protein = amount.protein
        copy.carbohydrates = amount.carbohydrates
        copy.fat = amount.fat
        return copy
    }

    /// The same calories as `food`: real macros, and the weight that food would need to be.
    ///
    /// The calories stay because they're the tested number, so a match can change the macros but never the total.
    /// This is only for when someone taps a dish: done automatically, it made the macros slightly worse.
    func matched(to food: FoodProduct) -> MealEstimate? {
        guard let perGram = food.nutritionPerGram, perGram.calories > 0 else { return nil }
        var copy = self
        let grams = calories / perGram.calories
        copy.grams = grams
        let amount = perGram.scaled(by: grams)
        copy.protein = amount.protein
        copy.carbohydrates = amount.carbohydrates
        copy.fat = amount.fat
        return copy
    }
}

/// Spots one food on its own, using the labels from Apple's image classifier.
///
/// The plate model has only seen meals, so anything small or simple needs this. These foods are the ones Vision named
/// reliably: fruit, baked goods and a few drinks. It often has no label at all for eggs, rice, oatmeal or tea.
/// The checks were set on 112 photos, half of them dishes with fruit on top: 28 matched, and all were the right fruit.
enum WholeFood {
    static let minimumConfidence: Float = 0.6
    /// Any of these in the photo means the food is part of something bigger.
    static let minimumMealConfidence: Float = 0.25
    /// A second food this close to the first means a platter.
    static let rivalRatio: Float = 0.6
    /// The plate model can't size a banana, but it does see a meal: banana on French toast read 675, and a lone
    /// fruit never passed 458.
    static let maximumEstimatedCalories = 500.0

    /// Foods to recognise, each with the labels Vision also gives it, which say nothing about the rest of the photo.
    private static let foods: [String: Set<String>] = {
        let drink: Set<String> = ["drink", "liquid", "cup", "bottle", "mug"]
        return [
            "apple": [], "avocado": [], "banana": [], "kiwi": [], "mandarine": [], "mango": [], "nectarine": [],
            "oranges": [], "peach": [], "pear": [], "plum": [],
            "bagel": ["bread", "baked_goods"],
            "croissant": ["bread", "baked_goods", "pastry"],
            "muffin": ["bread", "baked_goods", "dessert", "cake"],
            "cookie": ["baked_goods", "dessert", "chocolate", "candy"],
            "cupcake": ["cake", "baked_goods", "dessert"],
            "donut": ["cake", "baked_goods", "dessert", "pastry"],
            "pretzel": ["bread", "baked_goods"],
            "beer": drink, "coffee": drink,
            "red_wine": drink.union(["wine", "white_wine"]), "white_wine": drink.union(["wine", "red_wine"])
        ]
    }()
    private static let otherFruit: Set<String> = [
        "apricot", "blackberry", "blueberry", "cantaloupe", "cherry", "coconut", "cranberry", "fig", "grape", "grapefruit",
        "guava", "honeydew", "lemon", "lime", "lychee", "melon", "papaya", "passionfruit", "persimmon", "pineapple",
        "pomegranate", "raspberry", "strawberry", "watermelon"
    ]
    private static let mealSigns: Set<String> = [
        "baked_goods", "berry", "bowl", "bread", "cake", "candy", "cereal", "cheese", "chocolate", "cup", "dessert", "drink",
        "fork", "frozen_dessert", "ice_cream", "juice", "liquid", "meat", "oatmeal", "pancake", "pastry", "pie", "salad",
        "sandwich", "seasonings", "smoothie", "spoon", "vegetable", "waffle", "yogurt"
    ]

    /// The food in a photo, if that's all the photo shows.
    static func guess(labels: [String: Float], estimatedCalories: Double) -> DishGuess? {
        guard estimatedCalories <= maximumEstimatedCalories,
              let (label, confidence) = labels.filter({ foods[$0.key] != nil }).max(by: { $0.value < $1.value }),
              confidence >= minimumConfidence, let family = foods[label],
              !mealSigns.subtracting(family).contains(where: { (labels[$0] ?? 0) >= minimumMealConfidence }),
              !labels.contains(where: { rival in
                  rival.key != label && !family.contains(rival.key) && (foods[rival.key] != nil || otherFruit.contains(rival.key))
                      && rival.value >= confidence * rivalRatio
              })
        else { return nil }
        return DishGuess(label: label, confidence: Double(confidence))
    }
}

enum DishFoods {
    private struct Entry: Decodable {
        let food: String
        let source: Int
        /// Calories, protein, carbs, fat, sodium, sugars, fiber.
        let perGram: [Double]
        /// Set for foods eaten one at a time, which are named by Vision's labels rather than Food-101's.
        var itemGrams: Double?
        var title: String?
    }

    private static let table: [String: Entry] = {
        guard let url = Bundle.main.url(forResource: "dish_foods", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }()

    /// The food for something eaten one at a time.
    static func match(for guess: DishGuess) -> DishMatch? {
        guard let food = food(for: guess.label), let entry = table[guess.label], let grams = entry.itemGrams else { return nil }
        return DishMatch(dish: DishGuess(label: guess.label, confidence: guess.confidence, title: entry.title), food: food, itemGrams: grams)
    }

    /// The food for a Food-101 dish. Nil for dishes with no honest equivalent, which keep the photo estimate.
    static func food(for label: String) -> FoodProduct? {
        guard let entry = table[label], entry.perGram.count == 7 else { return nil }
        let amounts = entry.perGram.map { $0 * 100 }
        return FoodProduct(
            id: "dish-\(label)",
            name: entry.food,
            serving: "100 g",
            nutrition: Nutrition(
                calories: amounts[0], protein: amounts[1], carbohydrates: amounts[2], fat: amounts[3],
                sodiumMilligrams: amounts[4], sugars: amounts[5], fiber: amounts[6]
            ),
            source: entry.source == 3 ? .canadianNutrientFile : .usda,
            servingGrams: 100
        )
    }
}
