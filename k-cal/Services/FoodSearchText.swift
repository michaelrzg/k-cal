//
//  FoodSearchText.swift
//  k-cal
//
//  How food text is turned into searchable words. tools/food_database/build.py does the same when it builds the
//  index, so the two have to stay in step.
//

import Foundation

enum FoodSearchText {
    /// Words that say little about a food: they never have to match, and a search isn't judged on them.
    static let fillerWords: Set<String> = ["a", "an", "and", "at", "by", "for", "from", "in", "n", "of", "on", "or", "the", "to", "w", "with"]

    /// Lowercased, without accents or apostrophes, so "Reese's" and "reeses" are the same word.
    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
            .filter { !"'\u{2019}`".contains($0) }
            .replacingOccurrences(of: "&", with: " and ")
    }

    static func words(in text: String) -> [String] {
        normalized(text).split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// Joined spellings the tokenizer would otherwise split: Chick-fil-A as chickfila, Dr Pepper as drpepper.
    static func aliases(name: String, brand: String?) -> String {
        var found = Set<String>()
        let brandWords = words(in: brand ?? "")
        if brandWords.count > 1 {
            found.insert(brandWords.joined())
            found.insert(brandWords.filter { $0 != "and" }.joined())
        }
        for word in normalized(name).split(whereSeparator: \.isWhitespace) where word.contains("-") {
            let pieces = word.split { !$0.isLetter && !$0.isNumber && $0 != "-" }.joined()
            if pieces.contains("-") { found.insert(pieces.replacingOccurrences(of: "-", with: "")) }
        }
        return found.sorted().joined(separator: " ")
    }
}
