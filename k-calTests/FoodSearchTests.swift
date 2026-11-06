//
//  FoodSearchTests.swift
//  k-calTests
//

import Foundation
import Testing
@testable import k_cal

struct FoodSearchTextTests {
    @Test func spellingsOfTheSameWordMatch() {
        #expect(FoodSearchText.words(in: "Reese's Peanut Butter") == ["reeses", "peanut", "butter"])
        #expect(FoodSearchText.words(in: "Reese’s") == ["reeses"])
        #expect(FoodSearchText.words(in: "Ben & Jerry's") == ["ben", "and", "jerrys"])
        #expect(FoodSearchText.words(in: "Crème Brûlée") == ["creme", "brulee"])
    }

    @Test func joinsBrandsAndHyphenatedNames() {
        #expect(FoodSearchText.aliases(name: "Sandwich", brand: "Chick-fil-A") == "chickfila")
        #expect(FoodSearchText.aliases(name: "Cola", brand: "Dr Pepper") == "drpepper")
        #expect(FoodSearchText.aliases(name: "Ice Cream", brand: "Ben & Jerry's") == "benandjerrys benjerrys")
        #expect(FoodSearchText.aliases(name: "Stir-Fry Sauce", brand: nil) == "stirfry")
        #expect(FoodSearchText.aliases(name: "Oats", brand: "Quaker") == "")
    }
}

struct FoodVocabularyTests {
    private let vocabulary = FoodVocabulary(entries: [
        ("chicken", 90000), ("chiken", 13), ("sandwich", 12000), ("broccoli", 8000), ("peanut", 9000), ("butter", 30000),
        ("banana", 7000), ("bread", 40000), ("cheddar", 6000), ("yogurt", 9000), ("rye", 900), ("ice", 12000), ("cream", 40000),
    ])

    @Test func knowsItsWordsAndPrefixes() {
        #expect(vocabulary.frequency(of: "chicken") == 90000)
        #expect(vocabulary.frequency(of: "chick") == 0)
        #expect(vocabulary.hasWord(startingWith: "chick"))
        #expect(!vocabulary.hasWord(startingWith: "zebra"))
    }

    @Test func fixesEachKindOfTypo() {
        #expect(vocabulary.corrections(for: "brocolli") == ["broccoli"])     // two edits
        #expect(vocabulary.corrections(for: "sandwhich") == ["sandwich"])    // swapped letters
        #expect(vocabulary.corrections(for: "bananna") == ["banana"])        // extra letter
        #expect(vocabulary.corrections(for: "yogrt") == ["yogurt"])          // missing letter
        #expect(vocabulary.corrections(for: "cheddat") == ["cheddar"])       // wrong letter
    }

    @Test func treatsARareSpellingAsATypoOfACommonWord() {
        #expect(vocabulary.corrections(for: "chiken") == ["chicken"])
    }

    @Test func leavesGoodAndUnfinishedWordsAlone() {
        #expect(vocabulary.corrections(for: "chicken").isEmpty)
        #expect(vocabulary.corrections(for: "sandw").isEmpty)
        #expect(vocabulary.corrections(for: "zzqxv").isEmpty)
        #expect(vocabulary.corrections(for: "12345").isEmpty)
    }

    @Test func splitsWordsRunTogether() {
        #expect(vocabulary.split("peanutbutter") == ["peanut", "butter"])
        #expect(vocabulary.split("icecream") == ["ice", "cream"])
        #expect(vocabulary.split("chicken") == nil)
    }
}

struct FoodSearchPlanTests {
    private let vocabulary = FoodVocabulary(entries: [
        ("chicken", 90000), ("sandwich", 12000), ("mcdonalds", 900), ("big", 9000), ("mac", 3000), ("peanut", 9000), ("butter", 30000),
    ])

    @Test func strictNeedsEveryWordAsTyped() {
        #expect(FoodSearchPlan(query: "big mac", vocabulary: nil).strict == "\"big\"* AND \"mac\"*")
    }

    @Test func offersCorrectionsAlongsideWhatWasTyped() {
        let plan = FoodSearchPlan(query: "chiken sandwich", vocabulary: vocabulary)
        #expect(plan.corrected == "(\"chiken\"* OR \"chicken\"*) AND \"sandwich\"*")
        #expect(plan.partial == "(\"chiken\"* OR \"chicken\"*) OR \"sandwich\"*")
    }

    @Test func splitsAndJoins() {
        #expect(FoodSearchPlan(query: "peanutbutter", vocabulary: vocabulary).corrected == "(\"peanutbutter\"* OR (\"peanut\"* AND \"butter\"*))")
        #expect(FoodSearchPlan(query: "mc donalds", vocabulary: vocabulary).joined == ["mcdonalds"])
    }

    @Test func fillerWordsNeverHaveToMatch() {
        #expect(FoodSearchPlan(query: "ben and jerrys", vocabulary: nil).strict == "\"ben\"* AND \"jerrys\"*")
        #expect(FoodSearchPlan(query: "the", vocabulary: nil).strict == "\"the\"*")
    }

    @Test func oneWordHasNothingToLoosen() {
        #expect(FoodSearchPlan(query: "chicken", vocabulary: vocabulary).corrected == nil)
        #expect(FoodSearchPlan(query: "chicken", vocabulary: vocabulary).partial == nil)
        #expect(FoodSearchPlan(query: "  ", vocabulary: vocabulary).strict == nil)
    }
}

struct LocalIndexMigrationTests {
    /// A phone that fetched foods before the search index changed.
    @Test func foodsFetchedUnderTheOldIndexAreStillFound() throws {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).sqlite")
        do {
            let old = try SQLite(url: url, readOnly: false)
            try old.execute("""
            CREATE TABLE food(barcode INTEGER PRIMARY KEY, name TEXT NOT NULL, brand TEXT, serving TEXT NOT NULL,
                image TEXT, ingredients TEXT, calories INTEGER, protein INTEGER, carbohydrates INTEGER, fat INTEGER,
                sodium INTEGER, sugars INTEGER, fiber INTEGER);
            CREATE VIRTUAL TABLE food_search USING fts5(text, tokenize="unicode61 remove_diacritics 2");
            INSERT INTO food(barcode, name, brand, serving, calories) VALUES (812345678905, 'Spicy Sandwich', 'Chick-fil-A', '1', 4000);
            INSERT INTO food_search(rowid, text) VALUES (812345678905, 'Spicy Sandwich Chick-fil-A');
            """)
        }
        let migrated = try LocalFoodDatabase(url: url)
        #expect(try migrated.count() == 1)
        #expect(try migrated.search("\"chickfila\"*").map(\.name) == ["Spicy Sandwich"])
        #expect(try migrated.search("\"sandwiches\"*").count == 1)
        _ = try LocalFoodDatabase(url: url)
        #expect(try migrated.search("\"spicy\"*").count == 1)
    }
}

struct FoodRankingTests {
    private func product(_ name: String, brand: String? = nil, barcode: String? = "812345678905", popularity: Int = 0) -> FoodProduct {
        FoodProduct(id: UUID().uuidString, name: name, brand: brand, barcode: barcode == "812345678905" ? "81234567\(Int.random(in: 1000 ... 9999))5" : barcode,
                    serving: "1 serving", nutrition: Nutrition(calories: 1), source: .openFoodFacts, popularity: popularity)
    }

    private func names(_ products: [FoodProduct], _ query: String, familiar: Set<String> = []) -> [String] {
        FoodRanking.rank(products, plan: FoodSearchPlan(query: query, vocabulary: nil), familiar: familiar).map(\.name)
    }

    @Test func matchingEveryWordBeatsAnythingElse() {
        #expect(names([product("Chicken Soup", popularity: 100_000), product("Spicy Chicken Sandwich")], "spicy chicken sandwich").first == "Spicy Chicken Sandwich")
    }

    @Test func aBrandInTheQueryCounts() {
        let list = [product("Spicy Chicken Sandwich", brand: "Wendy's"), product("Spicy Chicken Sandwich", brand: "Chick-fil-A", barcode: nil)]
        #expect(FoodRanking.rank(list, plan: FoodSearchPlan(query: "spicy chicken sandwich chickfila", vocabulary: nil)).first?.brand == "Chick-fil-A")
    }

    @Test func popularityBreaksATie() {
        #expect(names([product("Cheerios Cereal A"), product("Cheerios Cereal B", popularity: 5000)], "cheerios cereal").first == "Cheerios Cereal B")
    }

    @Test func familiarFoodsComeFirstAmongEquals() {
        #expect(names([product("Greek Yogurt A"), product("Greek Yogurt B")], "greek yogurt", familiar: ["greek yogurt b"]).first == "Greek Yogurt B")
    }

    @Test func extraWordsCountAgainstAFood() {
        #expect(names([product("Chicken Breast Strips in Sauce"), product("Chicken Breast")], "chicken breast").first == "Chicken Breast")
    }
}

/// The searches that matter, against the real database.
struct RealFoodSearchTests {
    private struct Offline: OnlineFoodSource {
        func search(_: String) async throws -> [FoodProduct] { [] }
        func product(barcode _: String) async throws -> FoodProduct? { nil }
    }

    private func repository() throws -> FoodRepository {
        let url = try #require(Bundle.main.url(forResource: "foods", withExtension: "sqlite"))
        return FoodRepository(bundled: try BundledFoodDatabase(url: url), local: nil, online: Offline())
    }

    @Test(arguments: [
        ("spicy chicken sandwich chickfila", "chick-fil-a"), ("innout", "in-n-out"), ("in n out burger", "in-n-out"), ("taco bell crunchwrap", "crunchwrap"), ("chipotle burrito", "chipotle"), ("wendys frosty", "frosty"), ("starbucks caramel macchiato", "macchiato"), ("dominos pizza", "pizza"), ("in n out double double", "in-n-out"), ("chickfila", "chick-fil"), ("chick fil a", "chick-fil"), ("chik fil a", "chick-fil"),
        ("mcdonalds big mac", "big mac"), ("mc donalds big mac", "big mac"), ("mcdonald's big mac", "big mac"), ("big mak", "big mac"),
        ("drpepper", "pepper"), ("dr peper", "pepper"), ("cocacola", "coca"), ("coca cola", "coca"), ("coka cola", "coca"), ("mcdonals fries", "fries"), ("chocolate chip cookes", "cookie"), ("protien bar", "protein"),
        ("chiken breast", "chicken"), ("sandwhich", "sandwich"), ("brocolli", "broccoli"), ("yougurt greek", "yogurt"), ("bananna", "banana"),
        ("tomatos", "tomato"), ("peanutbutter", "peanut butter"), ("icecream", "ice cream"), ("starbucks frapuccino", "frappuccino"),
        ("ben and jerrys", "ben"), ("reeses", "reese"), ("cheerios", "cheerios"), ("french fries", "fries"), ("hersheys kisses", "kiss"),
    ])
    func findsWhatWasMeant(query: String, expected: String) async throws {
        let results = try await repository().search(query, online: false)
        let top = results.prefix(5).map { "\($0.name) \($0.brand ?? "")".lowercased() }
        #expect(top.contains { $0.contains(expected) }, "\(query) gave \(top)")
    }

    @Test func namingAChainPutsItsMenuFirst() async throws {
        let first = try await repository().search("spicy chicken sandwich chickfila", online: false).first
        #expect(first?.source == .restaurant)
        #expect(first?.brand == "Chick-fil-A")
        #expect(first?.serving.contains("menu") == true)
    }

    @Test func restaurantItemsDoNotCrowdOutPlainFoods() async throws {
        #expect(try await repository().search("banana", online: false).first?.source != .restaurant)
    }
}
