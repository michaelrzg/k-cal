//
//  PackageMatcher.swift
//  k-cal
//
//  Works out which product a photo of a package shows, from the words printed on it.
//

import CoreGraphics
import Foundation

enum PackageMatcher {
    /// Below this share of a product's own words appearing on the package, a match is more likely to be a coincidence.
    static let minimumCoverage = 0.6
    /// To treat a photo as a package at all, its best match has to fit this well, with its brand on show. On 349 packages
    /// and 1,000 meal photos that caught 83% of the packages and 1.8% of the meals, some of which had a package in them.
    static let minimumPackageCoverage = 0.75
    private static let maximumQueryWords = 8

    /// Words all over packaging that say nothing about which product it is.
    private static let packagingWords: Set<String> = [
        "net", "wt", "weight", "oz", "lb", "lbs", "g", "kg", "ml", "l", "fl", "ct", "pack", "new", "real", "natural", "naturally", "flavored",
        "flavor", "flavour", "gluten", "free", "non", "gmo", "project", "verified", "organic", "usda", "kosher", "contains", "made", "best",
        "by", "per", "serving", "servings", "calories", "total", "fat", "sugar", "sugars", "sodium", "protein", "daily", "value", "high",
        "low", "source", "good", "great", "taste", "tasty", "delicious", "family", "size", "value", "premium", "quality", "since", "brand",
        "original", "classic", "style", "no", "not", "all", "only", "you", "your", "our", "we", "more", "less", "than", "is", "it"
    ]

    /// A brand and product someone has read off the package, as print big enough to be searched for first.
    static func namedPieces(brand: String, product: String) -> [LabelText] {
        [(brand, 2.0), (product, 1.5)].filter { !$0.0.isEmpty }.map { LabelText(text: $0.0, box: CGRect(x: 0, y: 0, width: 1, height: $0.1)) }
    }

    /// Words worth searching for, biggest print first. Size is what separates a product's name from the small print.
    /// - Parameter vocabulary: the database's words, for putting right what OCR misreads: "starkista" for StarKist.
    static func searchWords(in texts: [LabelText], vocabulary: FoodVocabulary? = nil) -> [(word: String, size: Double)] {
        var sizes: [String: Double] = [:]
        for piece in texts {
            for raw in FoodSearchText.words(in: piece.text) where raw.count > 1 && raw.contains(where: \.isLetter) {
                let word = vocabulary.flatMap { $0.frequency(of: raw) == 0 ? $0.corrections(for: raw).first : nil } ?? raw
                sizes[word] = max(sizes[word] ?? 0, Double(piece.box.height))
            }
        }
        return sizes.map { (word: $0.key, size: $0.value) }.sorted { $0.size == $1.size ? $0.word < $1.word : $0.size > $1.size }
    }

    /// FTS queries from strict to loose: the biggest words together, then pairs of them.
    static func queries(for words: [(word: String, size: Double)]) -> [String] {
        let useful = words.filter { !packagingWords.contains($0.word) && !FoodSearchText.fillerWords.contains($0.word) }
            .prefix(maximumQueryWords).map { "\"\($0.word)\"" }
        guard !useful.isEmpty else { return [] }
        var queries = [useful.prefix(3).joined(separator: " AND ")]
        for first in useful.indices {
            for second in useful.indices where second > first {
                queries.append("\(useful[first]) AND \(useful[second])")
            }
        }
        if queries.count == 1 || useful.count == 1 { queries.append(useful[0]) }
        return queries
    }

    /// How well a product fits the words on the package, from 0 to 1. Everything in its name has to be on the package,
    /// but much on the package won't be in its name.
    static func coverage(of product: FoodProduct, seen: Set<String>) -> Double {
        let own = Set(FoodSearchText.words(in: "\(product.brand ?? "") \(product.name)"))
            .filter { !FoodSearchText.fillerWords.contains($0) && $0.contains(where: \.isLetter) && $0.count > 1 && !packagingUnits.contains($0) }
        guard !own.isEmpty else { return 0 }
        return Double(own.filter { seen.contains($0) || seen.contains($0 + "s") || seen.contains(String($0.dropLast())) }.count) / Double(own.count)
    }

    private static let packagingUnits: Set<String> = ["oz", "ounce", "ounces", "bag", "box", "pack", "plastic", "canister", "bottle", "can", "lb", "ct", "count", "pk"]

    /// True if every word of the product's brand is on the package.
    static func brandIsVisible(_ product: FoodProduct, seen: Set<String>) -> Bool {
        let words = FoodSearchText.words(in: product.brand ?? "").filter { $0.count > 1 }
        return !words.isEmpty && words.allSatisfy(seen.contains)
    }

    /// Products to offer for a package. Empty if the photo probably isn't of one, when it should go on as a meal.
    static func choices(_ candidates: [FoodProduct], texts: [LabelText], vocabulary: FoodVocabulary? = nil, limit: Int = 5) -> [FoodProduct] {
        let ranked = rank(candidates, texts: texts, vocabulary: vocabulary, limit: limit)
        let seen = Set(searchWords(in: texts, vocabulary: vocabulary).map(\.word))
        guard let best = ranked.first, best.coverage >= minimumPackageCoverage, brandIsVisible(best.product, seen: seen) else { return [] }
        return ranked.filter { $0.coverage >= minimumCoverage }.map(\.product)
    }

    /// The likeliest products, best first.
    static func rank(_ candidates: [FoodProduct], texts: [LabelText], vocabulary: FoodVocabulary? = nil, limit: Int = 5) -> [(product: FoodProduct, coverage: Double)] {
        let words = searchWords(in: texts, vocabulary: vocabulary)
        let seen = Set(words.map(\.word))
        let biggest = Dictionary(words.map { ($0.word, $0.size) }, uniquingKeysWith: max)
        let largest = words.first?.size ?? 1
        func score(_ product: FoodProduct, _ coverage: Double) -> Double {
            let nameWords = FoodSearchText.words(in: product.name)
            let printed = nameWords.compactMap { biggest[$0] }.reduce(0, +) / max(largest * Double(max(nameWords.count, 1)), 0.0001)
            let scans = log10(Double(product.popularity) + 1) / 3
            // A brand on the package counts for more than anything: a plain "Greek Yogurt" fits every yogurt's label.
            return coverage + (brandIsVisible(product, seen: seen) ? 1.5 : product.brand == nil ? -0.3 : 0) + printed * 0.5 + scans * 0.4
        }
        var seenIDs = Set<String>()
        return candidates
            .filter { seenIDs.insert($0.id).inserted }
            .map { (product: $0, coverage: coverage(of: $0, seen: seen)) }
            .sorted { score($0.product, $0.coverage) > score($1.product, $1.coverage) }
            .prefix(limit).map { $0 }
    }
}
