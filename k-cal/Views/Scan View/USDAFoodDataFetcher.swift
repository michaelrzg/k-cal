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

                    guard let name = product["product_name"] as? String,
                          let nutriments = product["nutriments"] as? [String: Any] else {
                        completion(nil, "Missing data in JSON")
                        return
                    }

                    let caloriesPerServing = self.extractNutrientValue(from: nutriments, for: "energy-kcal_serving") ?? 0
                    let protein = self.extractNutrientValue(from: nutriments, for: "proteins_serving") ?? 0
                    let carbohydrates = self.extractNutrientValue(from: nutriments, for: "carbohydrates_serving") ?? 0
                    let fat = self.extractNutrientValue(from: nutriments, for: "fat_serving") ?? 0

                    let newFood = Food(name: name, day: day, protein: protein, carbohydrates: carbohydrates, fat: fat, meal: .breakfast, servings: 1, calories_per_serving: caloriesPerServing)
                    context.insert(newFood)
                    print("ran")
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
