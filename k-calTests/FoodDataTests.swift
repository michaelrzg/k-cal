//
//  FoodDataTests.swift
//  k-calTests
//
//  JSON fixtures follow real responses from each service.
//

import Foundation
import SwiftData
import Testing
@testable import k_cal

struct BarcodeTests {
    @Test func sameProductComparesEqualAcrossFormats() {
        #expect(Barcode.canonical("049000028904") == "49000028904")
        #expect(Barcode.canonical("0049000028904") == "49000028904")
        #expect(Barcode.canonical("00049000028904") == "49000028904")
    }

    @Test func rejectsWhatIsNotABarcode() {
        #expect(Barcode.canonical("123") == nil)
        #expect(Barcode.canonical("00000000") == nil)
        #expect(Barcode.canonical("https://example.com/not/a/product/code/at/all/123456789012345") == nil)
    }

    @Test func spellsEveryPadding() {
        #expect(Barcode.spellings(of: "0049000028904") == ["049000028904", "0049000028904", "00049000028904"])
    }

    @Test func expandsUPCE() {
        #expect(Barcode.expandUPCE("04252614") == "042100005264")  // last digit 1
        #expect(Barcode.expandUPCE("01234505") == "012000003455")  // last digit 0
        #expect(Barcode.expandUPCE("01234535") == "012300000455")  // last digit 3
        #expect(Barcode.expandUPCE("01234545") == "012340000055")
        #expect(Barcode.expandUPCE("01234565") == "012345000065")
        #expect(Barcode.expandUPCE("1234") == nil)
    }
}

struct OpenFoodFactsClientTests {
    private func parse(_ json: String) throws -> FoodProduct? {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        return try OpenFoodFactsClient.parse(#require(object), code: "0068100904901")
    }

    @Test func prefersPerServingValuesAndConvertsSodiumToMilligrams() throws {
        let food = try #require(try parse(#"""
        {"product_name":"Kraft Dinner","brands":"Kraft, Heinz","serving_size":"0.667 de tasse (85.0 g)",
        "nutriments":{"energy-kcal_100g":365,"energy-kcal_serving":310,"sodium_100g":0.66,"sodium_serving":0.561,"sugars_100g":8}}
        """#))
        #expect(food.brand == "Kraft")
        #expect(food.serving == "0.667 de tasse (85.0 g)")
        #expect(food.nutrition.calories == 310)
        #expect(abs(food.nutrition.sodiumMilligrams - 561) < 0.001)
    }

    @Test func scalesPer100GramValuesToAKnownServing() throws {
        let food = try #require(try parse(#"""
        {"product_name":"Snack","serving_quantity":"30","serving_size":"30 g",
        "nutriments":{"energy-kcal_100g":500,"proteins_100g":10}}
        """#))
        #expect(food.serving == "30 g")
        #expect(food.nutrition.calories == 150)
        #expect(food.nutrition.protein == 3)
    }

    @Test func labelsPer100GramsInsteadOfPretendingItIsAServing() throws {
        let food = try #require(try parse(#"""
        {"product_name":"Cereal","serving_size":"a bowl","nutriments":{"energy-kcal_100g":400}}
        """#))
        #expect(food.serving == "100 g")
        #expect(food.nutrition.calories == 400)
    }

    @Test func keepsARealZeroCalorieDrink() throws {
        let food = try #require(try parse(#"{"product_name":"Diet","nutriments":{"energy-kcal_100g":0}}"#))
        #expect(food.nutrition.calories == 0)
    }

    @Test func skipsProductsWithoutEnergy() throws {
        #expect(try parse(#"{"product_name":"Nothing","nutriments":{}}"#) == nil)
        #expect(try parse(#"{"nutriments":{"energy-kcal_100g":10}}"#) == nil)
    }
}

struct OpenFoodFactsExportTests {
    private func record(_ json: String) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    @Test func scalesAggregatedNutritionToTheServing() throws {
        let food = try #require(OpenFoodFactsClient.parseExport(try record(#"""
        {"code":"0838154000658","product_name":"Beef Jerky Bites","brands":"Niman's Land, Other","serving_quantity":50,
        "serving_size":"1 portion (50 g)","countries_tags":["en:united-states"],"nutrition":{"aggregated_set":{"per":"100g",
        "nutrients":{"energy-kcal":{"value":300,"unit":"kcal"},"proteins":{"value":60,"unit":"g"},"sodium":{"value":1.2,"unit":"g"}}}}}
        """#)))
        #expect(food.brand == "Niman's Land")
        #expect(food.serving == "1 portion (50 g)")
        #expect(food.nutrition.calories == 150)
        #expect(food.nutrition.protein == 30)
        #expect(abs(food.nutrition.sodiumMilligrams - 600) < 0.001)
    }

    @Test func sodiumInMilligramsIsNotConverted() throws {
        let food = try #require(OpenFoodFactsClient.parseExport(try record(#"""
        {"code":"0838154000658","product_name":"Soup","countries_tags":["en:canada"],"nutrition":{"aggregated_set":{"per":"100ml",
        "nutrients":{"energy-kcal":{"value":40,"unit":"kcal"},"sodium":{"value":300,"unit":"mg"}}}}}
        """#)))
        #expect(food.serving == "100 ml")
        #expect(food.nutrition.sodiumMilligrams == 300)
    }

    @Test func skipsWhatCannotBeLogged() throws {
        let nutrition = #""nutrition":{"aggregated_set":{"nutrients":{"energy-kcal":{"value":40}}}}"#
        #expect(OpenFoodFactsClient.parseExport(try record(#"{"code":"0838154000658","product_name":"French","countries_tags":["en:france"],\#(nutrition)}"#)) == nil)
        #expect(OpenFoodFactsClient.parseExport(try record(#"{"code":"12","product_name":"Bad code","countries_tags":["en:canada"],\#(nutrition)}"#)) == nil)
        #expect(OpenFoodFactsClient.parseExport(try record(#"{"code":"0838154000658","countries_tags":["en:canada"],\#(nutrition)}"#)) == nil)
        #expect(OpenFoodFactsClient.parseExport(try record(#"{"code":"0838154000658","product_name":"No data","countries_tags":["en:canada"],"nutrition":{}}"#)) == nil)
    }
}

struct FoodUpdatePlanTests {
    private let index = """
    openfoodfacts_products_300_400.json.gz
    openfoodfacts_products_100_200.json.gz
    openfoodfacts_products_200_300.json.gz
    something_else.txt
    """

    @Test func appliesOldestFirstAndSkipsWhatIsDone() {
        #expect(FoodUpdatePlan.pending(index: index, after: 200).map(\.end) == [300, 400])
        #expect(FoodUpdatePlan.pending(index: index, after: 0).map(\.end) == [200, 300, 400])
        #expect(FoodUpdatePlan.pending(index: index, after: 400).isEmpty)
    }
}

struct GzipLineReaderTests {
    /// gzip of "first\nsecond\n" followed by a second member holding "third", as `gzip -n` writes them.
    private static let twoMembers = "1f8b08000000000000034bcb2c2a2ee12a4e4dcecf4be10200205145080d0000001f8b08000000000000032bc9c82c4a01006420322405000000"

    private func file(_ hex: String) throws -> URL {
        let bytes = stride(from: 0, to: hex.count, by: 2).map { offset -> UInt8 in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return UInt8(hex[start ..< hex.index(start, offsetBy: 2)], radix: 16)!
        }
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try Data(bytes).write(to: url)
        return url
    }

    @Test func readsLinesAcrossMembers() throws {
        var lines: [String] = []
        try GzipLineReader.forEachLine(in: file(Self.twoMembers)) { lines.append(String(decoding: $0, as: UTF8.self)) }
        #expect(lines == ["first", "second", "third"])
    }

    @Test func rejectsOtherFiles() throws {
        #expect(throws: GzipLineReader.Failure.self) {
            try GzipLineReader.forEachLine(in: file("68656c6c6f20776f726c6420746869732069732074657874")) { _ in }
        }
    }
}

struct FoodRepositoryTests {
    private struct Online: OnlineFoodSource {
        var results: [FoodProduct] = []
        var match: FoodProduct?
        var fails = false

        func search(_: String) async throws -> [FoodProduct] {
            if fails { throw URLError(.notConnectedToInternet) }
            return results
        }

        func product(barcode _: String) async throws -> FoodProduct? {
            if fails { throw URLError(.notConnectedToInternet) }
            return match
        }
    }

    private func product(_ name: String, brand: String? = nil, barcode: String? = nil, source: FoodProduct.Source = .usda) -> FoodProduct {
        FoodProduct(id: "\(source)-\(name)-\(barcode ?? "")", name: name, brand: brand, barcode: barcode,
                    serving: "1 cup", nutrition: Nutrition(calories: 12.5, sodiumMilligrams: 3), source: source)
    }

    private func match(_ query: String) -> String {
        FoodSearchPlan(query: query, vocabulary: nil).strict!
    }

    private func ranked(_ products: [FoodProduct], _ query: String) -> [FoodProduct] {
        FoodRanking.rank(products, plan: FoodSearchPlan(query: query, vocabulary: nil))
    }

    private func localDatabase() throws -> LocalFoodDatabase {
        try LocalFoodDatabase(url: URL.temporaryDirectory.appending(path: "\(UUID().uuidString).sqlite"))
    }

    private func bundled() throws -> BundledFoodDatabase {
        try BundledFoodDatabase(url: #require(Bundle.main.url(forResource: "foods", withExtension: "sqlite")))
    }

    @Test func localDatabaseKeepsAndFindsFoods() throws {
        let local = try localDatabase()
        try local.save([product("Maple Oat Bites", brand: "Acme", barcode: "0049000028904")])
        let found = try #require(try local.product(barcode: "049000028904"))
        #expect(found.name == "Maple Oat Bites")
        #expect(found.nutrition.calories == 12.5)
        #expect(try local.search(match("acme map")).count == 1)
    }

    @Test func newerCopyReplacesTheOldOne() throws {
        let local = try localDatabase()
        try local.save([product("Old recipe", barcode: "049000028904")])
        try local.save([product("New recipe", barcode: "049000028904")])
        #expect(try local.count() == 1)
        #expect(try local.search(match("old")).isEmpty)
        #expect(try local.search(match("new")).map(\.name) == ["New recipe"])
    }

    @Test func updatedProductOverridesTheBundledOne() async throws {
        let local = try localDatabase()
        try local.save([product("Updated Greek Yogurt", barcode: "031200037206")])
        let repository = try FoodRepository(bundled: bundled(), local: local, online: Online(fails: true))
        #expect(try await repository.product(barcode: "031200037206")?.name == "Updated Greek Yogurt")
    }

    @Test func barcodeInTheBundleNeedsNoNetwork() async throws {
        let repository = try FoodRepository(bundled: bundled(), local: localDatabase(), online: Online(fails: true))
        #expect(try await repository.product(barcode: "0031200037206")?.name == "Greek Yogurt")
    }

    @Test func missedBarcodeGoesOnlineAndIsKept() async throws {
        let local = try localDatabase()
        let online = Online(match: product("Brand New Snack", barcode: "812345678905", source: .openFoodFacts))
        let repository = FoodRepository(bundled: nil, local: local, online: online)
        #expect(try await repository.product(barcode: "812345678905")?.name == "Brand New Snack")
        let offline = FoodRepository(bundled: nil, local: local, online: Online(fails: true))
        #expect(try await offline.product(barcode: "812345678905")?.name == "Brand New Snack")
    }

    @Test func unknownBarcodeIsNotAnError() async throws {
        let repository = try FoodRepository(bundled: nil, local: localDatabase(), online: Online())
        #expect(try await repository.product(barcode: "812345678905") == nil)
    }

    @Test func missedBarcodeOfflineIsAnError() async throws {
        let repository = try FoodRepository(bundled: nil, local: localDatabase(), online: Online(fails: true))
        await #expect(throws: FoodRepositoryError.self) { try await repository.product(barcode: "812345678905") }
    }

    @Test func thinSearchAsksOnlineAndKeepsTheResults() async throws {
        let local = try localDatabase()
        let online = Online(results: [product("Zorblax Bar", barcode: "812345678905", source: .openFoodFacts)])
        let repository = FoodRepository(bundled: nil, local: local, online: online)
        #expect(try await repository.search("zorblax").map(\.name) == ["Zorblax Bar"])
        #expect(try local.search(match("zorblax")).count == 1)
    }

    @Test func offlineSearchWithResultsIsNotAnError() async throws {
        let local = try localDatabase()
        try local.save([product("Zorblax Bar", barcode: "812345678905")])
        let repository = FoodRepository(bundled: nil, local: local, online: Online(fails: true))
        #expect(try await repository.search("zorblax").count == 1)
    }

    @Test func offlineSearchWithNothingIsAnError() async throws {
        let repository = try FoodRepository(bundled: nil, local: localDatabase(), online: Online(fails: true))
        await #expect(throws: FoodRepositoryError.self) { try await repository.search("zorblax") }
    }

    @Test func wholeWordsBeatWordStartsAndPlainerFoodsWinTies() async throws {
        let order = ranked([
            product("Bananamilk"), product("Banana Nut Butter Granola"), product("Banana, raw"), product("Crackers"),
        ], "banana")
        #expect(order.map(\.name).first == "Banana, raw")
        #expect(order.map(\.name).last == "Crackers")
    }

    @Test func plainFoodBeatsABrandedOneWithTheSameName() {
        let another = ranked([product("Banana", brand: "Dole", barcode: "812345678905"), product("Banana, raw")], "banana")
        #expect(another.map(\.name) == ["Banana, raw", "Banana"])
    }

    @Test func duplicatesKeepTheEarlierCopy() {
        let order = ranked([
            product("Cola", barcode: "049000028904"),
            product("Coca-Cola Can", barcode: "0049000028904", source: .openFoodFacts),
            product("Banana", source: .canadianNutrientFile),
            product("BANANA"),
        ], "x")
        #expect(order.map(\.name) == ["Banana", "Cola"])  // the plain food sorts first
    }

    @Test func bundledDatabaseAnswersOffline() async throws {
        let repository = try FoodRepository(bundled: bundled(), local: localDatabase(), online: Online(fails: true))
        let bananas = try await repository.search("banana")
        #expect(bananas.first?.name.lowercased().contains("banana") == true)
        #expect(try bundled().count() > 1_000_000)
        #expect(try bundled().dataDate() > 0)
    }
}

@MainActor
struct LoggingTests {
    private let context: ModelContext

    init() throws {
        let container = try ModelContainer(
            for: User.self, Day.self, Food.self, Search.self, CustomFood.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    @Test func customFoodBecomesOneServingOfFood() throws {
        let custom = CustomFood(name: "Gran's chili", serving: "1 bowl", calories: 420, protein: 30, carbohydrates: 35, fat: 18, sodium: 900, barcode: "049000028904")
        context.insert(custom)
        let food = Food(product: custom.product, day: Day(date: Date()), meal: .dinner)
        #expect(food.name == "Gran's chili")
        #expect(food.calories == 420)
        #expect(food.protein == 30)
        #expect(food.sodium == 900)
        #expect(food.serving == "1 bowl")
    }

    @Test func customFoodMatching() {
        let custom = CustomFood(name: "Gran's chili", brand: "Home", calories: 1, barcode: "0049000028904")
        #expect(custom.matches("chi"))
        #expect(custom.matches("home gran"))
        #expect(!custom.matches("soup"))
        #expect(custom.hasBarcode("049000028904"))
        #expect(!custom.hasBarcode("049000028911"))
    }

    @Test func findsTheSameDayInsteadOfMakingAnother() throws {
        let morning = Date()
        let day = try Day.find(morning, in: context)
        let later = try Day.find(morning.addingTimeInterval(1), in: context)
        #expect(day === later)
        #expect(day.date == Calendar.current.startOfDay(for: morning))
    }

    @Test func movingAFoodLeavesTheRestOfTheDayAlone() throws {
        let today = try Day.find(Date(), in: context)
        let yesterday = try Day.find(Date().addingTimeInterval(-86400), in: context)
        let first = Food(product: FoodProduct(id: "a", name: "A", serving: "1", nutrition: Nutrition(calories: 1), source: .usda), day: today, meal: .snack)
        let second = Food(product: FoodProduct(id: "b", name: "B", serving: "1", nutrition: Nutrition(calories: 1), source: .usda), day: today, meal: .snack)
        context.insert(first)
        context.insert(second)
        first.day = yesterday
        try context.save()
        #expect(first.isLogged(on: yesterday.date))
        #expect(second.isLogged(on: today.date))
    }

    @Test func loggingAgainStartsFromOneServing() {
        let day = Day(date: Date())
        let logged = Food(name: "Oats", day: day, protein: 5, carbohydrates: 30, fat: 3, meal: .breakfast, servings: 3, calories_per_serving: 150, sodium: 10, sugars: 1, fiber: 4, ingredients: nil, url: nil, barcode: nil, brand: nil)
        let again = Food(copying: logged, day: day, meal: .lunch)
        #expect(again.servings == 1)
        #expect(again.calories == 150)
        #expect(again.protein == 5)
        #expect(again.meal == "Lunch")
    }

    /// Cancelling AddFoodSheet must leave nothing behind.
    @Test func foodUnderReviewIsNotLoggedUntilSaved() throws {
        let day = Day(date: Calendar.current.startOfDay(for: Date()))
        context.insert(day)
        try context.save()
        let food = Food(product: FoodProduct(id: "x", name: "Apple", serving: "1", nutrition: Nutrition(calories: 95), source: .usda), day: day, meal: .snack)
        food.day = Day(date: day.date)   // what AddFoodSheet.init does
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Food>()) == 0)
    }
}
