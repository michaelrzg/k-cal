//
//  ActivityLevel.swift
//  k-cal
//
//  The starting goals for how active someone is.
//

import Foundation

enum ActivityLevel: String, CaseIterable, Identifiable {
    case lightlyActive = "Light"
    case moderatelyActive = "Moderate"
    case veryActive = "Very Active"

    var id: String { rawValue }

    var suggestedCalories: Int {
        switch self {
        case .lightlyActive: 2000
        case .moderatelyActive: 2500
        case .veryActive: 3000
        }
    }

    /// Grams of each macro for a calorie goal: 4 calories a gram of protein or carbs, 9 of fat.
    func macros(forCalories calories: Int) -> (protein: Int, carbohydrates: Int, fat: Int) {
        let shares: (protein: Double, carbohydrates: Double, fat: Double) = switch self {
        case .lightlyActive: (0.20, 0.55, 0.25)
        case .moderatelyActive: (0.25, 0.55, 0.20)
        case .veryActive: (0.30, 0.50, 0.20)
        }
        let total = Double(calories)
        return (Int(total * shares.protein / 4), Int(total * shares.carbohydrates / 4), Int(total * shares.fat / 9))
    }
}
