//
//  FoodRanking.swift
//  k-cal
//
//  Puts the food the user most likely means first. The heaviest signal is how much of the query a food matches,
//  so nothing that misses a word can outrank one that has them all. The rest settle the order among those.
//

import Foundation

enum FoodRanking {
    private struct Candidate {
        let product: FoodProduct
        let offset: Int
        let score: Double
    }

    /// Removes duplicates, then ranks.
    /// - Parameter familiar: lowercased names of foods the user has logged.
    static func rank(_ products: [FoodProduct], plan: FoodSearchPlan, familiar: Set<String> = []) -> [FoodProduct] {
        var seen = Set<String>()
        let unique = products.filter { product in
            let barcode = product.barcode.flatMap(Barcode.canonical)
            let keys = [barcode, "\(product.name)|\(product.brand ?? "")".lowercased()].compactMap { $0 }
            let isNew = keys.allSatisfy { !seen.contains($0) }
            seen.formUnion(keys)
            return isNew
        }
        let queryIsBranded = unique.contains { matchesBrand($0, plan: plan) }
        var candidates: [Candidate] = []
        candidates.reserveCapacity(unique.count)
        for (offset, product) in unique.enumerated() {
            let value = score(product, plan: plan, familiar: familiar, queryIsBranded: queryIsBranded)
            candidates.append(Candidate(product: product, offset: offset, score: value))
        }
        candidates.sort { $0.score == $1.score ? $0.offset < $1.offset : $0.score > $1.score }
        return candidates.map(\.product)
    }

    private static func compact(_ words: [String]) -> String {
        words.filter { $0 != "and" }.joined()
    }

    private static func stem(_ word: String) -> String {
        guard word.count > 3 else { return word }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.hasSuffix("s"), !word.hasSuffix("ss") { return String(word.dropLast()) }
        return word
    }

    private static func contains(_ words: Set<String>, _ spellings: [String]) -> Bool {
        spellings.contains { spelling in
            spelling.split(separator: " ").map(String.init).allSatisfy { part in
                words.contains(stem(part)) || words.contains { $0.count > part.count && $0.hasPrefix(part) }
            }
        }
    }

    /// True when some word of the query names this product's brand, however it was spelled.
    private static func matchesBrand(_ product: FoodProduct, plan: FoodSearchPlan) -> Bool {
        guard let brand = product.brand else { return false }
        let brandWords = FoodSearchText.words(in: brand)
        let joined = compact(brandWords)
        guard joined.count > 2 else { return false }
        let wholeQuery = plan.terms.map(\.word).joined()
        if plan.joined.contains(joined) || plan.spellings.contains(where: { $0.contains(joined) }) || wholeQuery.contains(joined) {
            return true
        }
        // People drop the end of a chain's name: "in n out" for In-N-Out Burger. It takes two or more of its words,
        // or any burger would count as Burger King.
        return brandWords.count > 2 && stride(from: brandWords.count - 1, to: 1, by: -1).contains { count in
            let start = compact(Array(brandWords.prefix(count)))
            return start.count >= 5 && wholeQuery.contains(start)
        }
    }

    private static func score(_ product: FoodProduct, plan: FoodSearchPlan, familiar: Set<String>, queryIsBranded: Bool) -> Double {
        let nameWords = FoodSearchText.words(in: product.name)
        // USDA's "Milk, whole, 3.25% milkfat" is plain milk: what follows the comma only describes it.
        let headWords = FoodSearchText.words(in: product.name.split(separator: ",").first.map(String.init) ?? product.name)
        let names = Set(nameWords.map(stem))
        let brandWords = FoodSearchText.words(in: product.brand ?? "")
        let brands = Set(brandWords.map(stem))
        let joinedBrand = compact(brandWords)
        let joinedName = compact(nameWords)
        let isPlainFood = product.brand == nil && product.barcode == nil

        let spellings = plan.spellings
        guard !spellings.isEmpty else { return 0 }
        var matched = 0.0
        var inName = 0.0
        for term in spellings {
            let hitName = contains(names, term) || term.contains { $0.count > 3 && joinedName.contains($0.replacingOccurrences(of: " ", with: "")) }
            if hitName || contains(brands, term) || (!joinedBrand.isEmpty && term.contains(joinedBrand)) {
                matched += 1
                if hitName { inName += 1 }
            }
        }
        let count = Double(spellings.count)
        // Written as one word in the query, like "koka kola" for Coca-Cola, it's a match for all of them.
        if plan.joined.contains(where: { $0 == joinedBrand || joinedName.contains($0) }) { matched = count }
        var score = matched / count * 1000
        score += inName / count * 60

        // Spelled the likeliest way, not the way it was typed: "Sandwich" beats a label that says "Sandwhich".
        let phrase = plan.preferredPhrase.map(stem).joined(separator: " ")
        let head = headWords.map(stem).joined(separator: " ")
        let name = nameWords.map(stem).joined(separator: " ")
        if head == phrase { score += 50 } else if head.hasPrefix(phrase) { score += 30 } else if name.contains(phrase) { score += 18 }
        // A misspelling on a label loses to the real word, but a word split in two was only ever a guess.
        let typedLikeALabelTypo = plan.terms.contains { term in
            !term.alternatives.isEmpty && !term.alternatives[0].contains(" ") && names.contains(stem(term.word))
        }
        if typedLikeALabelTypo { score -= 25 }

        if matchesBrand(product, plan: plan) {
            score += 90
            // The menu, not the bottled sauce: a chain's own items count for more than what it sells in shops.
            if product.source == .restaurant { score += 60 }
        }
        // Asking for a plain food: USDA's "Bananas, raw", not somebody's banana bar.
        if isPlainFood, !queryIsBranded { score += 55 }
        // Words the user didn't ask for: "Chicken Breast" is a closer match than "Chicken Breast Strips in Sauce".
        score -= Double(max(headWords.count - plan.preferredPhrase.count, 0)) * 7
        score -= Double(nameWords.count) * 0.5

        score += min(log2(Double(product.popularity) + 1), 10) * 3
        if !product.serving.isEmpty, product.serving != "100 g" { score += 4 }
        // Manufacturers' US labels, over crowd-sourced entries from wherever.
        if product.source == .usda { score += 8 }
        if familiar.contains(product.name.lowercased()) { score += 70 }
        return score
    }
}
