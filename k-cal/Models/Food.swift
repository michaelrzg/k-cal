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
    @Relationship var day: Day
    
    init(name: String, calories: Int, timeEaten: Date? = nil, day: Day, protein: Int = 0, carbohydrates: Int = 0, fat: Int = 0, meal: Meal, servings: Int = 1) {
        self.name = name
        self.calories = calories
        self.timeEaten = timeEaten
        self.day = day
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.servings=servings
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
    }
}

enum Meal{
    
        case breakfast
        case lunch
        case dinner
        case snack

    
}
