//
//  Database.swift
//  k-cal
//
//  Created by Michael Rizig on 2/10/25.
//

import Foundation
import SwiftData

@Model
class Day: Identifiable {
    @Attribute(.unique) var date: Date
    var foods: [Food] = []
    
    var totalCalories: Int {
        foods.reduce(0) { $0 + $1.calories}
        
    }
    var totalProtein: Int {
        foods.reduce(0) { $0 + $1.protein }
    }
    var totalCarbohydrates: Int {
        foods.reduce(0) { $0 + $1.carbohydrates }
    }
    var totalFat: Int {
        foods.reduce(0) { $0 + $1.fat }
    }
    
    init(date: Date) {
        self.date = date
    }
}

@Model
class Food: Identifiable {
    var name: String
    var calories: Int
    var timeEaten: Date?
    var protein: Int
    var carbohydrates: Int
    var fat: Int
    
    @Relationship var day: Day
    
    init(name: String, calories: Int, timeEaten: Date? = nil, day: Day, protein: Int = 0, carbohydrates: Int = 0, fat: Int = 0) {
        self.name = name
        self.calories = calories
        self.timeEaten = timeEaten
        self.day = day
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
    }
}


