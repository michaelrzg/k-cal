import Foundation
import SwiftData

class OpenFoodFactsFetcher {

    private let baseURL = "https://world.openfoodfacts.org/api/v0/product/"

    func fetchFoodData(forBarcode barcode: String, context: ModelContext, day: Day, completion: @escaping (Food?, String?) -> Void) {
        
        guard let url = URL(string: "\(baseURL)\(barcode).json") else {
            completion(nil, "Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(nil, error.localizedDescription)
                return
            }

            guard let data = data else {
                completion(nil, "No data received")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let product = json["product"] as? [String: Any] {
                    print(json)
                    
                    guard let name = product["product_name"] as? String,
                          let nutriments = product["nutriments"] as? [String: Any] else {
                        completion(nil, "Missing data in JSON")
                        return
                    }

                    let caloriesPerServing = self.extractNutrientValue(from: nutriments, for: "energy-kcal_serving") ?? self.extractNutrientValue(from: nutriments, for: "energy-kcal") ?? 0
                    let protein = self.extractNutrientValue(from: nutriments, for: "proteins_serving") ?? self.extractNutrientValue(from: nutriments, for: "proteins") ?? 0
                    let carbohydrates = self.extractNutrientValue(from: nutriments, for: "carbohydrates_serving") ?? self.extractNutrientValue(from: nutriments, for: "carbohydrates") ?? 0
                    let fat = self.extractNutrientValue(from: nutriments, for: "fat_serving") ?? self.extractNutrientValue(from: nutriments, for: "fat") ?? 0
                    let sugar = self.extractNutrientValue(from: nutriments, for: "sugars") ?? 0
                    let fiber = self.extractNutrientValue(from: nutriments, for: "fiber") ?? 0
                    let sodium = self.extractNutrientValue(from: nutriments, for: "sodium") ?? 0

                    // Grab ingredients
                    let ingredients = product["ingredients_text"] as? String ?? "No ingredients available"

                    let newFood = Food(
                        name: name,
                        day: day,
                        protein: protein,
                        carbohydrates: carbohydrates,
                        fat: fat,
                        meal: .breakfast,
                        servings: 1,
                        calories_per_serving: caloriesPerServing,
                        sodium: sugar,
                        sugars: fiber,
                        fiber: sodium,
                        ingredients: ingredients
                    )

                    context.insert(newFood)
                    print("Food data inserted successfully.")
                    
                    try context.save()
                    completion(newFood, nil)

                } else {
                    completion(nil, "Invalid JSON structure or product not found")
                }
            } catch {
                completion(nil, error.localizedDescription)
            }
        }

        task.resume()
    }

    private func extractNutrientValue(from nutriments: [String: Any], for nutrientKey: String) -> Int? {
        if let value = nutriments[nutrientKey] as? Double {
            return Int(value)
        } else if let value = nutriments[nutrientKey] as? String, let doubleValue = Double(value) {
            return Int(doubleValue)
        }
        return nil
    }
}
