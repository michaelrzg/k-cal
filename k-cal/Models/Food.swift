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
    @Relationship var day: Day?
    
    init(name: String, day: Day, protein: Int, carbohydrates: Int, fat: Int , meal: Meal, servings: Int , calories_per_serving: Int ) {
        self.name = name
        self.timeEaten = day.date
        self.day = day
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.servings=servings
        self.calories_per_serving = calories_per_serving
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
