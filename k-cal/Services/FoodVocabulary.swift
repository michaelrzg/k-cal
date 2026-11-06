//
//  FoodVocabulary.swift
//  k-cal
//
//  Every word in the food database and how common it is, for telling what the user meant. Held as one block of
//  bytes, sorted, so hundreds of thousands of words stay small in memory and quick to scan.
//

import Foundation

final class FoodVocabulary: Sendable {
    /// Below this a word is too rare to be offered as a correction: it could be a typo in the data itself.
    private static let minimumCorrectionFrequency = 8
    /// A word this much rarer than a near neighbour is treated as a misspelling of it, even though it's in the
    /// data: "chiken" appears on real labels, a few times against tens of thousands of "chicken".
    private static let dataTypoRatio = 40
    private static let minimumSplitFrequency = 40
    private static let unfinishedWordLength = 5
    private static let maximumCorrections = 3
    private static let certainlyCorrectFrequency = 2000

    private let bytes: [UInt8]
    private let offsets: [Int32]
    private let frequencies: [Int32]

    /// - Parameter entries: words and how often each appears. Any order.
    init(entries: [(word: String, frequency: Int)]) {
        let sorted = entries.map { (Array($0.word.utf8), $0.frequency) }.sorted { $0.0.lexicographicallyPrecedes($1.0) }
        var bytes: [UInt8] = []
        var offsets: [Int32] = [0]
        var frequencies: [Int32] = []
        bytes.reserveCapacity(sorted.count * 8)
        for (word, frequency) in sorted {
            bytes.append(contentsOf: word)
            offsets.append(Int32(bytes.count))
            frequencies.append(Int32(min(frequency, Int(Int32.max))))
        }
        self.bytes = bytes
        self.offsets = offsets
        self.frequencies = frequencies
    }

    var count: Int {
        frequencies.count
    }

    /// How often `word` appears, or 0.
    func frequency(of word: String) -> Int {
        let target = Array(word.utf8)
        let index = lowerBound(target)
        return index < count && compare(index, target) == 0 ? Int(frequencies[index]) : 0
    }

    /// True if any word starts with `prefix`, as a word still being typed does.
    func hasWord(startingWith prefix: String) -> Bool {
        let target = Array(prefix.utf8)
        let index = lowerBound(target)
        guard index < count else { return false }
        let start = Int(offsets[index])
        return Int(offsets[index + 1]) - start >= target.count && bytes[start ..< start + target.count].elementsEqual(target)
    }

    /// The words the user probably meant by `term`, likeliest first, if it doesn't look right as it stands.
    func corrections(for term: String) -> [String] {
        let target = Array(term.utf8)
        guard target.count >= 3, target.count <= 24, target.allSatisfy({ $0 < 128 }), !target.allSatisfy(isDigit) else { return [] }
        let known = frequency(of: term)
        // Too common to be a mistake.
        if known >= Self.certainlyCorrectFrequency { return [] }
        // A longer word that starts like this is probably still being typed. A short one could be either.
        if known == 0, target.count >= Self.unfinishedWordLength, hasWord(startingWith: term) { return [] }

        let limit = target.count <= 4 ? 1 : 2
        var best: [(index: Int, rank: Int, frequency: Int32)] = []
        var row0 = [Int](repeating: 0, count: 28)
        var row1 = row0
        var row2 = row0
        bytes.withUnsafeBufferPointer { all in
            for index in 0 ..< count {
                let start = Int(offsets[index])
                let length = Int(offsets[index + 1]) - start
                let frequency = frequencies[index]
                guard abs(length - target.count) <= limit, length <= 24, Int(frequency) >= Self.minimumCorrectionFrequency,
                      Int(frequency) >= max(known, 1) * Self.dataTypoRatio || known == 0 else { continue }
                let word = UnsafeBufferPointer(rebasing: all[start ..< start + length])
                let distance = Self.editDistance(target, word, limit: limit, &row0, &row1, &row2)
                guard distance <= limit, distance > 0 else { continue }
                // A closer word wins, then a more common one. The first letter is rarely the one that's wrong.
                let rank = distance * 2 + (word[0] == target[0] ? 0 : 1)
                best.append((index, rank, frequency))
                best.sort { $0.rank == $1.rank ? $0.frequency > $1.frequency : $0.rank < $1.rank }
                if best.count > Self.maximumCorrections { best.removeLast() }
            }
        }
        return best.map { word(at: $0.index) }
    }

    /// Two words run together, like "peanutbutter".
    func split(_ term: String) -> [String]? {
        let characters = Array(term)
        guard characters.count >= 5, frequency(of: term) < Self.minimumCorrectionFrequency * Self.dataTypoRatio else { return nil }
        var best: (first: String, second: String, score: Int)?
        for cut in 2 ... max(2, characters.count - 2) where cut < characters.count {
            let first = String(characters[..<cut])
            let second = String(characters[cut...])
            let score = min(frequency(of: first), frequency(of: second))
            if score >= Self.minimumSplitFrequency, score > (best?.score ?? 0) {
                best = (first, second, score)
            }
        }
        return best.map { [$0.first, $0.second] }
    }

    private func word(at index: Int) -> String {
        String(decoding: bytes[Int(offsets[index]) ..< Int(offsets[index + 1])], as: UTF8.self)
    }

    private func isDigit(_ byte: UInt8) -> Bool {
        (48 ... 57).contains(byte)
    }

    /// Negative when the word at `index` sorts before `target`.
    private func compare(_ index: Int, _ target: [UInt8]) -> Int {
        let start = Int(offsets[index])
        let length = Int(offsets[index + 1]) - start
        for position in 0 ..< min(length, target.count) where bytes[start + position] != target[position] {
            return Int(bytes[start + position]) - Int(target[position])
        }
        return length - target.count
    }

    private func lowerBound(_ target: [UInt8]) -> Int {
        var low = 0
        var high = count
        while low < high {
            let middle = (low + high) / 2
            if compare(middle, target) < 0 { low = middle + 1 } else { high = middle }
        }
        return low
    }

    /// Damerau-Levenshtein distance, counting a swap of neighbours as one edit, and giving up past `limit`.
    private static func editDistance(_ a: [UInt8], _ b: UnsafeBufferPointer<UInt8>, limit: Int, _ previous2: inout [Int], _ previous: inout [Int], _ current: inout [Int]) -> Int {
        let width = b.count
        for j in 0 ... width { previous[j] = j }
        for i in 1 ... a.count {
            current[0] = i
            var smallest = i
            for j in 1 ... max(width, 1) where width > 0 {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                var value = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    value = min(value, previous2[j - 2] + 1)
                }
                current[j] = value
                smallest = min(smallest, value)
            }
            if smallest > limit { return limit + 1 }
            swap(&previous2, &previous)
            swap(&previous, &current)
        }
        return previous[width]
    }
}
