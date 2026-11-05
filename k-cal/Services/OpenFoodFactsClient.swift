//
//  OpenFoodFactsClient.swift
//  k-cal
//
//  Open Food Facts, https://openfoodfacts.github.io/openfoodfacts-server/api/: the live fallback for foods
//  that aren't on the device, needing no key. Search is limited to products sold in the US and Canada. Its
//  limits are per user: about 15 barcode reads and 10 searches a minute. Open Database Licence.
//

import Foundation

struct OpenFoodFactsClient: OnlineFoodSource {
    private static let host = "https://world.openfoodfacts.org"
    private static let fields = "code,product_name,product_name_en,brands,serving_size,serving_quantity,image_small_url,image_url,ingredients_text_en,ingredients_text,nutriments"

    func search(_ query: String) async throws -> [FoodProduct] {
        // One request per country: a second country tag would mean sold in both.
        async let unitedStates = try? search(query, country: "united-states")
        async let canada = try? search(query, country: "canada")
        let (american, canadian) = await (unitedStates, canada)
        guard american != nil || canadian != nil else { throw FoodRepositoryError.unavailable }
        return (american ?? []) + (canadian ?? [])
    }

    private func search(_ query: String, country: String) async throws -> [FoodProduct] {
        var components = URLComponents(string: "\(Self.host)/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "15"),
            URLQueryItem(name: "sort_by", value: "unique_scans_n"),
            URLQueryItem(name: "tagtype_0", value: "countries"),
            URLQueryItem(name: "tag_contains_0", value: "contains"),
            URLQueryItem(name: "tag_0", value: country),
            URLQueryItem(name: "fields", value: Self.fields),
        ]
        return try Self.parseSearch(try await FoodHTTP.get(components.url!))
    }

    func product(barcode: String) async throws -> FoodProduct? {
        guard let code = Barcode.spellings(of: barcode).dropFirst().first else { return nil }
        var components = URLComponents(string: "\(Self.host)/api/v2/product/\(code).json")!
        components.queryItems = [URLQueryItem(name: "fields", value: Self.fields)]
        do {
            let json = try JSONSerialization.jsonObject(with: await FoodHTTP.get(components.url!)) as? [String: Any]
            return (json?["product"] as? [String: Any]).flatMap { Self.parse($0, code: code) }
        } catch FoodHTTP.Failure.status(404) {
            return nil
        }
    }

    static func parseSearch(_ data: Data) throws -> [FoodProduct] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["products"] as? [[String: Any]] ?? []).compactMap { parse($0, code: $0["code"] as? String) }
    }

    /// Values arrive as numbers or strings, and a product may give them per serving, per 100 g, or both.
    /// Per 100 g is only used as a serving when the size of a real serving is unknown, and is labelled so.
    static func parse(_ product: [String: Any], code: String?) -> FoodProduct? {
        let names = [product["product_name_en"], product["product_name"]].compactMap { $0 as? String }
        guard let name = names.first(where: { !$0.isEmpty }),
              let nutriments = product["nutriments"] as? [String: Any]
        else { return nil }

        func amount(_ key: String, _ suffix: String) -> Double? {
            number(nutriments["\(key)_\(suffix)"])
        }

        let hasServingValues = amount("energy-kcal", "serving") != nil
        let servingGrams = number(product["serving_quantity"]).flatMap { $0 > 0 ? $0 : nil }
        guard hasServingValues || amount("energy-kcal", "100g") != nil else { return nil }

        func perServing(_ key: String) -> Double? {
            if let value = amount(key, "serving") { return value }
            guard let value = amount(key, "100g") else { return nil }
            return value * (servingGrams ?? 100) / 100
        }

        let usesRealServing = hasServingValues || servingGrams != nil
        let label = (product["serving_size"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let nutrition = Nutrition(
            calories: perServing("energy-kcal") ?? 0,
            protein: perServing("proteins") ?? 0,
            carbohydrates: perServing("carbohydrates") ?? 0,
            fat: perServing("fat") ?? 0,
            sodiumMilligrams: (perServing("sodium") ?? 0) * 1000,   // reported in grams
            sugars: perServing("sugars") ?? 0,
            fiber: perServing("fiber") ?? 0
        )
        let image = [product["image_small_url"], product["image_url"]].compactMap { $0 as? String }.first
        let brand = (product["brands"] as? String)?.split(separator: ",").first.map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        let ingredients = [product["ingredients_text_en"], product["ingredients_text"]]
            .compactMap { $0 as? String }.first { !$0.isEmpty }
        return FoodProduct(
            id: "off-\(code ?? name)",
            name: name,
            brand: brand,
            barcode: code,
            imageURL: image.flatMap(URL.init(string:)),
            serving: usesRealServing ? (label ?? "\(Int(servingGrams ?? 100)) g") : "100 g",
            ingredients: ingredients,
            nutrition: nutrition,
            source: .openFoodFacts
        )
    }

    /// A record from the daily export files, which have no per-serving values: their nutrition is an
    /// `aggregated_set` of amounts per 100 g or 100 ml, each with a unit. Only products sold in North America
    /// are kept.
    static func parseExport(_ product: [String: Any]) -> FoodProduct? {
        let countries = product["countries_tags"] as? [String] ?? []
        guard countries.contains("en:united-states") || countries.contains("en:canada"),
              let code = product["code"] as? String, Barcode.canonical(code) != nil,
              let names = [product["product_name_en"], product["product_name"]] as [Any?]?,
              let name = names.compactMap({ $0 as? String }).first(where: { !$0.isEmpty }),
              let nutrition = product["nutrition"] as? [String: Any],
              let set = nutrition["aggregated_set"] as? [String: Any],
              let nutrients = set["nutrients"] as? [String: Any]
        else { return nil }

        func amount(_ key: String) -> Double? {
            number((nutrients[key] as? [String: Any])?["value"])
        }
        guard let calories = amount("energy-kcal"), (0 ... 900).contains(calories) else { return nil }
        let sodium = nutrients["sodium"] as? [String: Any]
        let sodiumIsMilligrams = (sodium?["unit"] as? String)?.lowercased() == "mg"

        let perHundred = Nutrition(
            calories: calories,
            protein: amount("proteins") ?? 0,
            carbohydrates: amount("carbohydrates") ?? 0,
            fat: amount("fat") ?? 0,
            sodiumMilligrams: (amount("sodium") ?? 0) * (sodiumIsMilligrams ? 1 : 1000),
            sugars: amount("sugars") ?? 0,
            fiber: amount("fiber") ?? 0
        )
        let quantity = number(product["serving_quantity"]).flatMap { (0 ..< 3000).contains($0) && $0 > 0 ? $0 : nil }
        let label = (product["serving_size"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let image = [product["image_small_url"], product["image_url"]].compactMap { $0 as? String }.first
        let brand = (product["brands"] as? String)?.split(separator: ",").first.map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        return FoodProduct(
            id: "off-\(code)",
            name: name,
            brand: brand,
            barcode: code,
            imageURL: image.flatMap(URL.init(string:)),
            serving: quantity != nil ? (label ?? "\(Int(quantity!)) g") : "100 \(set["per"] as? String == "100ml" ? "ml" : "g")",
            nutrition: perHundred.scaled(by: (quantity ?? 100) / 100),
            source: .openFoodFacts
        )
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: number.doubleValue
        case let string as String: Double(string)
        default: nil
        }
    }
}
