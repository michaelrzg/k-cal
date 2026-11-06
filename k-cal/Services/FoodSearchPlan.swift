//
//  FoodSearchPlan.swift
//  k-cal
//
//  Turns what was typed into searches, from strictest to loosest, so a typo or one unknown word narrows the
//  results instead of emptying them.
//

import Foundation

struct FoodSearchPlan: Equatable {
    /// One word of the query and the other spellings it could stand for.
    struct Term: Equatable {
        let word: String
        var alternatives: [String] = []
        var isFiller: Bool { FoodSearchText.fillerWords.contains(word) }
    }

    let terms: [Term]
    /// Words of the query run together, like "mc donalds" for "mcdonalds".
    let joined: [String]

    init(query: String, vocabulary: FoodVocabulary?) {
        let words = FoodSearchText.words(in: query)
        var cache: [String: [String]] = [:]
        terms = words.map { word in
            guard let vocabulary, !FoodSearchText.fillerWords.contains(word) else { return Term(word: word) }
            var alternatives = cache[word] ?? vocabulary.corrections(for: word)
            if alternatives.isEmpty, let parts = vocabulary.split(word) {
                alternatives = [parts.joined(separator: " ")]
            }
            cache[word] = alternatives
            return Term(word: word, alternatives: alternatives)
        }
        joined = vocabulary.map { vocabulary in
            zip(words, words.dropFirst()).flatMap { first, second -> [String] in
                let word = first + second
                if vocabulary.frequency(of: word) >= 20 { return [word] }
                // "koka kola" as one misspelled word is "cocacola", where neither half gives it away.
                return word.count >= 7 ? Array(vocabulary.corrections(for: word).prefix(1)) : []
            } + Self.wholeQuery(words, vocabulary: vocabulary)
        } ?? []
    }

    /// All of it as one word, for names in three or more pieces like "chick fil a".
    private static func wholeQuery(_ words: [String], vocabulary: FoodVocabulary) -> [String] {
        guard words.count > 2 else { return [] }
        let word = words.joined()
        return vocabulary.frequency(of: word) >= 3 ? [word] : []
    }

    /// The words that have to count. If the query is nothing but filler, they all do.
    private var meaningful: [Term] {
        let found = terms.filter { !$0.isFiller }
        return found.isEmpty ? terms : found
    }

    private static func clause(_ word: String) -> String {
        let parts = word.split(separator: " ")
        // Only a word at the end of what's typed could be unfinished, but matching prefixes costs nothing and
        // lets "chick" find "chicken" anywhere in the query.
        return parts.count > 1 ? "(" + parts.map { "\"\($0)\"*" }.joined(separator: " AND ") + ")" : "\"\(word)\"*"
    }

    private func clause(for term: Term) -> String {
        let spellings = [term.word] + term.alternatives
        return spellings.count == 1 ? Self.clause(term.word) : "(" + spellings.map(Self.clause).joined(separator: " OR ") + ")"
    }

    /// Every word as typed. Nil if there's nothing to search for.
    var strict: String? {
        guard !meaningful.isEmpty else { return nil }
        return meaningful.map { Self.clause($0.word) }.joined(separator: " AND ")
    }

    /// Every word, in any of its spellings. Nil if that's no different from `strict`.
    var corrected: String? {
        guard !joined.isEmpty || meaningful.contains(where: { !$0.alternatives.isEmpty }) else { return nil }
        let all = meaningful.map(clause(for:)).joined(separator: " AND ")
        return joined.isEmpty ? all : "(\(all)) OR " + joined.map(Self.clause).joined(separator: " OR ")
    }

    /// Any of the words, for when no food has them all.
    var partial: String? {
        guard meaningful.count > 1 else { return nil }
        return meaningful.map(clause(for:)).joined(separator: " OR ")
    }

    /// True when some word looks misspelled, so the corrected search is worth running however much the strict
    /// one found: "sandwhich" is on over a hundred real labels.
    var hasCorrections: Bool {
        !joined.isEmpty || meaningful.contains { !$0.alternatives.isEmpty }
    }

    /// The most likely form of each word, for matching names as a phrase.
    var preferredPhrase: [String] {
        meaningful.flatMap { ($0.alternatives.first ?? $0.word).split(separator: " ").map(String.init) }
    }

    /// All the spellings of each word, for ranking. A word split in two stays one spelling with a space in it,
    /// so that both halves have to match.
    var spellings: [[String]] {
        meaningful.map { [$0.word] + $0.alternatives }
    }
}
