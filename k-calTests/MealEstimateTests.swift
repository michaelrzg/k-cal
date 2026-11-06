//
//  MealEstimateTests.swift
//  k-calTests
//

import Foundation
import Testing
@testable import k_cal

struct MealEstimateTests {
    private func logTotals(kcal: Double, grams: Double, fat: Double, carbs: Double, protein: Double) -> [Double] {
        [kcal, grams, fat, carbs, protein].map { log1p($0) }
    }

    private func estimate(dishes: [DishGuess] = []) throws -> MealEstimate {
        try #require(MealEstimate(logTotals: logTotals(kcal: 500, grams: 400, fat: 20, carbs: 50, protein: 25), dishes: dishes))
    }

    @Test func decodesLogTotals() throws {
        let meal = try estimate()
        #expect(abs(meal.calories - 500) < 1e-9)
        #expect(abs(meal.grams - 400) < 1e-9)
        #expect(abs(meal.fat - 20) < 1e-9)
        #expect(abs(meal.carbohydrates - 50) < 1e-9)
        #expect(abs(meal.protein - 25) < 1e-9)
    }

    @Test func clampsOutOfRangeLogTotals() throws {
        let meal = try #require(MealEstimate(logTotals: [-1, 20, 1, 1, 1], dishes: []))
        #expect(meal.calories == 0)
        #expect(abs(meal.grams - expm1(8)) < 1e-9)
    }

    @Test func rejectsUnusableOutput() {
        #expect(MealEstimate(logTotals: [1, 2, 3], dishes: []) == nil)
        #expect(MealEstimate(logTotals: [1, .nan, 1, 1, 1], dishes: []) == nil)
        #expect(MealEstimate(logTotals: [1, 0, 1, 1, 1], dishes: []) == nil)
    }

    @Test func scalingKeepsDensity() throws {
        let half = try estimate().scaled(toGrams: 200)
        #expect(abs(half.grams - 200) < 1e-9)
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
