//
//  CustomFood.swift
//  k-cal
//
//  A food the user entered themselves. All values are for one serving.
//

import Foundation
import SwiftData

@Model
class CustomFood: Identifiable {
    var name: String
    var brand: String
    var serving: String
    var calories: Int
    var protein: Int
    var carbohydrates: Int
    var fat: Int
    var sodium: Int
    var sugars: Int
    var fiber: Int
    var barcode: String
    var created: Date

    init(name: String, brand: String = "", serving: String = "", calories: Int, protein: Int = 0, carbohydrates: Int = 0, fat: Int = 0, sodium: Int = 0, sugars: Int = 0, fiber: Int = 0, barcode: String = "") {
        self.name = name
        self.brand = brand
        self.serving = serving
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.sodium = sodium
        self.sugars = sugars
        self.fiber = fiber
        self.barcode = barcode
        created = Date()
    }

    var product: FoodProduct {
        FoodProduct(
            id: "custom-\(persistentModelID.hashValue)",
            name: name,
            brand: brand.isEmpty ? nil : brand,
            barcode: barcode.isEmpty ? nil : barcode,
            serving: serving,
            nutrition: Nutrition(
                calories: Double(calories),
                protein: Double(protein),
                carbohydrates: Double(carbohydrates),
                fat: Double(fat),
                sodiumMilligrams: Double(sodium),
                sugars: Double(sugars),
                fiber: Double(fiber)
            ),
            source: .custom
        )
    }

    /// Case-insensitive word-prefix match on the name and brand.
    func matches(_ query: String) -> Bool {
        let words = FoodText.words(in: "\(name) \(brand)")
        return FoodText.words(in: query).allSatisfy { term in words.contains { $0.hasPrefix(term) } }
    }

    func hasBarcode(_ code: String) -> Bool {
        guard let wanted = Barcode.canonical(code) else { return false }
        return Barcode.canonical(barcode) == wanted
    }
}
