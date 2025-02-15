//
//  Day.swift
//  k-cal
//
//  Created by Michael Rizig on 2/11/25.
//

import Foundation
import SwiftData

@Model
class Day: Identifiable {
    @Attribute(.unique) var date: Date
    @Relationship(inverse: \Food.day) var foods: [Food] = []

    var totalCalories: Int {
        foods.reduce(0) { $0 + $1.calories }
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
