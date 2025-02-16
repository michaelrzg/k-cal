import Foundation
import SwiftData

class OpenFoodFactsFetcher {
    private let baseURL = "https://world.openfoodfacts.org/api/v0/product/"
    private let searchURL = "https://world.openfoodfacts.org/cgi/search.pl?search_terms="

    func fetchFoodData(forBarcode barcode: String, context: ModelContext, day: Day, completion: @escaping (Food?, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)\(barcode).json") else {
            completion(nil, "Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
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
                   let product = json["product"] as? [String: Any]
                {
                    guard let name = product["product_name"] as? String,
                          let nutriments = product["nutriments"] as? [String: Any]
                    else {
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
                    let url = product["image_url"] as? String ?? ""
                    let ingredients = product["ingredients_text"] as? String ?? "No ingredients available"

                    let newFood = Food(
                        name: name,
                        day: day,
                        protein: protein,
                        carbohydrates: carbohydrates,
                        fat: fat,
                        meal: .breakfast, // Or set the correct meal
                        servings: 1,
                        calories_per_serving: caloriesPerServing,
                        sodium: sodium,
                        sugars: sugar,
                        fiber: fiber,
                        ingredients: ingredients,
                        url: url
                    )
                    
                    print(newFood.url)
                    context.insert(newFood)
                    let search = Search(food: newFood, day: Date())
                    context.insert(search)

                    do {
                        try context.save()
                        completion(newFood, nil)
                    } catch {
                        completion(nil, error.localizedDescription)
                    }

                } else {
                    completion(nil, "Invalid JSON structure or product not found")
                }
            } catch {
                completion(nil, error.localizedDescription)
            }
        }

        task.resume()
    }

    func searchFood(for searchTerm: String, completion: @escaping ([FoodSearchItem]?, String?) -> Void) {
        guard let encodedSearchTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(searchURL)\(encodedSearchTerm)&search_options=0&sort_by=unique_scans_n&json=true")
        else {
            completion(nil, "Invalid search URL")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
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
                   let products = json["products"] as? [[String: Any]]
                {
                    var searchResults: [FoodSearchItem] = []

                    for product in products {
                        guard let name = product["product_name"] as? String,
                              let brand = product["brands"] as? String,
                              let imageURLString = product["image_front_thumb_url"] as? String,
                              let imageURL = URL(string: imageURLString)
                        else {
                            continue // Skip products with missing data
                        }

                        let barcode = product["code"] as? String ?? ""
                        let foodSearchItem = FoodSearchItem(name: name, brand: brand, barcode: barcode, imageURL: imageURL)
                        searchResults.append(foodSearchItem)
                    }

                    // Sorting Logic: Prioritize matches in product_name
                    let sortedResults = searchResults.sorted { item1, item2 in
                        let item1NameContainsSearch = item1.name.localizedCaseInsensitiveContains(searchTerm)
                        let item2NameContainsSearch = item2.name.localizedCaseInsensitiveContains(searchTerm)

                        if item1NameContainsSearch, !item2NameContainsSearch {
                            return true // item1 name contains search, item2 doesn't - item1 goes first
                        } else if !item1NameContainsSearch, item2NameContainsSearch {
                            return false // item2 name contains search, item1 doesn't - item2 goes first
                        } else {
                            return false // Both or neither contain search - maintain original order
                        }
                    }

                    completion(sortedResults, nil) // Return the sorted results

                } else {
                    completion(nil, "Invalid JSON structure or products not found")
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

struct FoodSearchItem: Identifiable {
    let id = UUID()
    let name: String
    let brand: String
    let barcode: String
    let imageURL: URL?
}
