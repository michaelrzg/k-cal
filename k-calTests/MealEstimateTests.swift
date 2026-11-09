//
//  MealEstimateTests.swift
//  k-calTests
//

import Foundation
import Testing
@testable import k_cal

struct MealEstimateTests {
    private func logTotals(kcal: Double, carbs: Double, protein: Double, fat: Double) -> [Double] {
        [kcal, carbs, protein, fat].map { log1p($0) }
    }

    private func estimate(dishes: [DishGuess] = []) throws -> MealEstimate {
        try #require(MealEstimate(logTotals: logTotals(kcal: 500, carbs: 50, protein: 25, fat: 20), dishes: dishes))
    }

    @Test func decodesLogTotals() throws {
        let meal = try estimate()
        #expect(abs(meal.calories - 500) < 1e-9)
        #expect(meal.grams == nil)
        #expect(abs(meal.fat - 20) < 1e-9)
        #expect(abs(meal.carbohydrates - 50) < 1e-9)
        #expect(abs(meal.protein - 25) < 1e-9)
    }

    @Test func clampsOutOfRangeLogTotals() throws {
        let meal = try #require(MealEstimate(logTotals: [20, -1, 1, 1], dishes: []))
        #expect(abs(meal.calories - expm1(9)) < 1e-9)
        #expect(meal.carbohydrates == 0)
    }

    @Test func rejectsUnusableOutput() {
        #expect(MealEstimate(logTotals: [1, 2, 3], dishes: []) == nil)
        #expect(MealEstimate(logTotals: [1, .nan, 1, 1], dishes: []) == nil)
        #expect(MealEstimate(logTotals: [0, 1, 1, 1], dishes: []) == nil)
    }

    @Test func aSmallerPortionScalesEverything() throws {
        let half = try estimate().scaled(by: 0.5)
        #expect(abs(half.calories - 250) < 1e-9)
        #expect(abs(half.fat - 10) < 1e-9)
        #expect(abs(half.carbohydrates - 25) < 1e-9)
        #expect(abs(half.protein - 12.5) < 1e-9)
    }

    @Test func namesTheDishOnlyWhenConfident() throws {
        let sure = try estimate(dishes: [DishGuess(label: "spaghetti_bolognese", confidence: 0.8)])
        #expect(sure.suggestedName == "Spaghetti Bolognese")
        let unsure = try estimate(dishes: [DishGuess(label: "pizza", confidence: 0.2)])
        #expect(unsure.suggestedName == MealEstimate.fallbackName)
        #expect(try estimate().suggestedName == MealEstimate.fallbackName)
    }

    @Test func anUnknownDishIsNamedAfterItsIngredients() throws {
        var meal = try estimate(dishes: [DishGuess(label: "omelette", confidence: 0.4)])
        meal.ingredients = ["scrambled eggs", "bacon", "toast", "butter"]
        #expect(meal.suggestedName == "Scrambled eggs, bacon, toast")
    }

    @Test func picksLikelyIngredientsWithoutRepeats() {
        let names = ["egg", "eggs", "bacon", "rice"]
        #expect(MealEstimate.likelyIngredients([0.98, 0.96, 0.92, 0.2], names: names) == ["egg", "bacon"])
        #expect(MealEstimate.likelyIngredients([0.1, 0.1, 0.1, 0.1], names: names).isEmpty)
    }

    @Test func offersOnlyPlausibleSuggestions() throws {
        let meal = try estimate(dishes: [DishGuess(label: "pizza", confidence: 0.6), DishGuess(label: "bruschetta", confidence: 0.01)])
        #expect(meal.suggestions.map(\.label) == ["pizza"])
    }

    @Test func activityLevelsKeepTheirMacroSplits() {
        let light = ActivityLevel.lightlyActive.macros(forCalories: 2000)
        #expect(light.protein == 100)
        #expect(light.carbohydrates == 275)
        #expect(light.fat == 55)
        #expect(ActivityLevel.veryActive.macros(forCalories: 3000).protein == 225)
        #expect(ActivityLevel.moderatelyActive.suggestedCalories == 2500)
    }

    @Test func picksMealByHour() {
        #expect(Meal(hour: 8) == .breakfast)
        #expect(Meal(hour: 12) == .lunch)
        #expect(Meal(hour: 16) == .snack)
        #expect(Meal(hour: 19) == .dinner)
        #expect(Meal(hour: 23) == .snack)
        #expect(Meal(hour: 2) == .snack)
    }

    @Test func buildsAFoodWithNoBarcode() throws {
        let food = Food(estimate: try estimate(), name: "  ", day: Day(date: Date()), meal: .dinner)
        #expect(food.name == MealEstimate.fallbackName)
        #expect(food.meal == "Dinner")
        #expect(food.calories == 500)
        #expect(food.calories_per_serving == 500)
        #expect(food.protein == 25)
        #expect(food.carbohydrates == 50)
        #expect(food.fat == 20)
        #expect(food.barcode.isEmpty)
    }
}

struct MealMatchingTests {
    private func food(calories: Double, grams: Double?) -> FoodProduct {
        FoodProduct(id: "x", name: "Pizza, cheese", serving: "1 slice", nutrition: Nutrition(calories: calories, protein: 12, carbohydrates: 30, fat: 10), source: .usda, servingGrams: grams)
    }

    private func estimate() throws -> MealEstimate {
        try #require(MealEstimate(logTotals: [log1p(500), log1p(50), log1p(25), log1p(20)], dishes: []))
    }

    @Test func aMatchKeepsTheCaloriesAndCorrectsTheRest() throws {
        let matched = try #require(try estimate().matched(to: food(calories: 250, grams: 100)))
        #expect(abs(matched.calories - 500) < 0.01)
        #expect(abs((matched.grams ?? 0) - 200) < 0.01)
        #expect(abs(matched.protein - 24) < 0.01)
        #expect(abs(matched.carbohydrates - 60) < 0.01)
    }

    @Test func aDenseFoodCanNeverDoubleTheCalories() throws {
        let matched = try #require(try estimate().matched(to: food(calories: 460, grams: 100)))
        #expect(abs(matched.calories - 500) < 0.01)
    }

    @Test func needsToKnowTheServingWeight() throws {
        #expect(try estimate().matched(to: food(calories: 280, grams: nil)) == nil)
        #expect(try estimate().matched(to: food(calories: 280, grams: 0)) == nil)
    }

    @Test func aDishIsOnlyEverAChoiceHoweverSureTheClassifierIs() throws {
        let sure = DishGuess(label: "pizza", confidence: 0.99)
        let confident = try #require(MealEstimate(logTotals: [5, 1, 1, 1], dishes: [sure]))
        let match = DishMatch(dish: sure, food: food(calories: 280, grams: 100))
        #expect(MealPhotoResult(estimate: confident, looksLikeFood: true, matches: [match]).preferredMatch == nil)
    }

    @Test func curatedDishesHaveTheRightFood() throws {
        #expect(try #require(DishFoods.food(for: "samosa")).name == "Samosa")
        #expect(try #require(DishFoods.food(for: "macarons")).name.contains("macaroon"))
        let pizza = try #require(DishFoods.food(for: "pizza"))
        #expect(pizza.nutrition.calories > 200 && pizza.nutrition.calories < 320)
        #expect(pizza.nutritionPerGram != nil)
    }

    @Test func dishesWithNoHonestEquivalentHaveNoFood() {
        #expect(DishFoods.food(for: "spaghetti_carbonara") == nil)
        #expect(DishFoods.food(for: "risotto") == nil)
        #expect(DishFoods.food(for: "caesar_salad") == nil)
    }
}

struct WholeFoodTests {
    private func estimate(calories: Double = 209, dishes: [DishGuess]) throws -> MealEstimate {
        try #require(MealEstimate(logTotals: [log1p(calories), log1p(39), log1p(20), log1p(1)], dishes: dishes))
    }

    @Test func recognisesAPieceOfFruit() {
        let guess = WholeFood.guess(labels: ["banana": 0.97, "food": 0.97, "fruit": 0.97, "plate": 0.8], estimatedCalories: 209)
        #expect(guess?.label == "banana")
    }

    @Test func leavesUnsureOrAbsentFruitAlone() {
        #expect(WholeFood.guess(labels: ["banana": 0.34, "food": 0.34], estimatedCalories: 209) == nil)
        #expect(WholeFood.guess(labels: ["pizza": 0.9, "food": 0.9], estimatedCalories: 700) == nil)
        #expect(WholeFood.guess(labels: [:], estimatedCalories: 209) == nil)
    }

    @Test func fruitInsideAMealIsNotAPieceOfFruit() {
        #expect(WholeFood.guess(labels: ["banana": 0.93, "fork": 0.94], estimatedCalories: 300) == nil)
        #expect(WholeFood.guess(labels: ["apple": 0.8, "pie": 0.71], estimatedCalories: 300) == nil)
        #expect(WholeFood.guess(labels: ["bagel": 0.8, "bread": 0.8, "salad": 0.4], estimatedCalories: 300) == nil)
        // No label gives it away, but the portion model sees a meal.
        #expect(WholeFood.guess(labels: ["banana": 0.89, "plate": 0.7], estimatedCalories: 732) == nil)
    }

    @Test func aPlateOfFruitIsNotOnePiece() {
        #expect(WholeFood.guess(labels: ["kiwi": 0.81, "pomegranate": 0.82], estimatedCalories: 300) == nil)
        #expect(WholeFood.guess(labels: ["banana": 0.9, "apple": 0.8], estimatedCalories: 300) == nil)
    }

    @Test func aLookalikeDoesNotCountAsASecondFruit() {
        #expect(WholeFood.guess(labels: ["apple": 0.94, "pear": 0.31], estimatedCalories: 200)?.label == "apple")
        #expect(WholeFood.guess(labels: ["peach": 0.82, "nectarine": 0.24], estimatedCalories: 200)?.label == "peach")
    }

    @Test func aFoodsOwnLabelsDontCountAgainstIt() {
        #expect(WholeFood.guess(labels: ["bagel": 0.7, "bread": 0.7, "baked_goods": 0.7], estimatedCalories: 300)?.label == "bagel")
        #expect(WholeFood.guess(labels: ["cupcake": 0.93, "cake": 0.93, "dessert": 0.9], estimatedCalories: 300)?.label == "cupcake")
        #expect(WholeFood.guess(labels: ["beer": 0.86, "bottle": 0.93, "drink": 0.9], estimatedCalories: 200)?.label == "beer")
        #expect(WholeFood.guess(labels: ["red_wine": 0.77, "wine": 0.77, "white_wine": 0.39, "drink": 0.8], estimatedCalories: 200)?.label == "red_wine")
    }

    @Test func aBananaGetsABanana() throws {
        let match = try #require(DishFoods.match(for: DishGuess(label: "banana", confidence: 0.97)))
        let meal = try #require(estimate(dishes: [match.dish]).matched(to: match))
        #expect(meal.grams == 118)
        #expect(meal.calories > 95 && meal.calories < 115)
        #expect(meal.protein < 2)
        #expect(meal.fat < 1)
        #expect(meal.carbohydrates > 22 && meal.carbohydrates < 32)
    }

    @Test func everyFruitHasTheRightFood() throws {
        for label in ["apple", "avocado", "banana", "kiwi", "mandarine", "mango", "nectarine", "oranges", "peach", "pear", "plum"] {
            let match = try #require(DishFoods.match(for: DishGuess(label: label, confidence: 0.9)), "\(label)")
            let meal = try #require(estimate(dishes: []).matched(to: match))
            #expect(meal.calories > 30 && meal.calories < 260, "\(label)")
            #expect(meal.protein < 4, "\(label)")
        }
        let expected: [String: ClosedRange<Double>] = [
            "bagel": 250 ... 300, "beer": 130 ... 170, "coffee": 0 ... 5, "cookie": 130 ... 160, "croissant": 220 ... 260,
            "cupcake": 230 ... 300, "donut": 290 ... 340, "muffin": 380 ... 460, "pretzel": 370 ... 410,
            "red_wine": 110 ... 135, "white_wine": 110 ... 130
        ]
        for (label, range) in expected {
            let match = try #require(DishFoods.match(for: DishGuess(label: label, confidence: 0.9)), "\(label)")
            let meal = try #require(estimate(dishes: []).matched(to: match))
            #expect(range.contains(meal.calories), "\(label) came to \(meal.calories)")
        }
        #expect(DishFoods.match(for: DishGuess(label: "oranges", confidence: 0.9))?.dish.name == "Orange")
    }

    @Test func foodsWithoutAPieceSizeAreNotFruit() {
        #expect(DishFoods.match(for: DishGuess(label: "pizza", confidence: 0.9)) == nil)
        #expect(DishFoods.match(for: DishGuess(label: "lettuce", confidence: 0.9)) == nil)
    }

    @Test func fruitIsPreferredBelowTheDishConfidence() throws {
        let match = try #require(DishFoods.match(for: DishGuess(label: "apple", confidence: 0.83)))
        let result = MealPhotoResult(estimate: try estimate(dishes: [match.dish]), looksLikeFood: true, matches: [match])
        #expect(result.preferredMatch == match)
    }
}

struct PhotoFoodNamerTests {
    @Test func makesATidyTitle() {
        #expect(PhotoFoodNamer.title(from: ["Chicken", " greens", "sauce "]) == "Chicken, greens, sauce")
    }

    @Test func dropsRepeatsAndStopsAtThree() {
        #expect(PhotoFoodNamer.title(from: ["rice", "Rice", "beans", "corn", "salsa"]) == "Rice, beans, corn")
    }

    @Test func hasNothingToSayWithoutNames() {
        #expect(PhotoFoodNamer.title(from: []) == nil)
        #expect(PhotoFoodNamer.title(from: ["  "]) == nil)
    }
}
