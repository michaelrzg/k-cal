//
//  Food.swift
//  k-cal
//
//  Created by Michael Rizig on 2/11/25.
//


import Foundation
import SwiftData


@Model
class Food: Identifiable {
    var name: String
    var calories: Int
    var timeEaten: Date?
    var protein: Int
    var carbohydrates: Int
    var fat: Int
    var meal: String
    var servings: Int = 1
    var calories_per_serving: Int
    var cholesterol: Int = 0
    var sodium: Int = 0
    var sugars: Int = 0
    var fiber: Int = 0
    var ingredients: String = ""
    @Relationship var day: Day?
    
    init(name: String, day: Day, protein: Int, carbohydrates: Int, fat: Int , meal: Meal, servings: Int , calories_per_serving: Int, sodium:Int?, sugars:Int?, fiber:Int?, ingredients: String? ) {
        self.name = name
        self.timeEaten = day.date
        self.day = day
        self.protein = protein * servings
        self.carbohydrates = carbohydrates * servings
        self.fat = fat * servings
        self.servings=servings
        self.calories_per_serving = calories_per_serving
        self.sodium = sodium ?? 0
        self.sugars = sugars ?? 0
        self.fiber = fiber ?? 0
        self.ingredients = ingredients ?? ""
        switch meal {
            case .breakfast:
                self.meal = "Breakfast"
            break
            case .lunch:
                self.meal = "Lunch"
            break;
            case .dinner:
                self.meal = "Dinner"
            break;
            case .snack:
                self.meal = "Snack"
            break;
        }
        
        self.calories = servings * calories_per_serving
    }
}

enum Meal{
    
        case breakfast
        case lunch
        case dinner
        case snack

    
}
