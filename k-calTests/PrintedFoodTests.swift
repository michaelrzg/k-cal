//
//  PrintedFoodTests.swift
//  k-calTests
//
//  The text here is what Vision really returned for real panels, misreads included.
//

import CoreGraphics
import Foundation
import Testing
@testable import k_cal

private func piece(_ text: String, y: CGFloat, x: CGFloat = 0.03, width: CGFloat = 0.5, height: CGFloat = 0.03) -> LabelText {
    LabelText(text: text, box: CGRect(x: x, y: y - height / 2, width: width, height: height))
}

struct NutritionLabelTests {
    /// Tortilla chips, with "8g" read as "Bg" and the calorie figure in a box of its own.
    private let chips = [
        piece("Nutrition Facts", y: 0.05),
        piece("9 servings per container", y: 0.11),
        piece("Serving size 1oz (28g/about 15 chips)", y: 0.15),
        piece("Amount per serving", y: 0.21),
        piece("150", y: 0.242, x: 0.7, width: 0.25, height: 0.06),
        piece("Calories", y: 0.251, height: 0.05),
        piece("% Daily Value*", y: 0.31, x: 0.62, width: 0.32),
        piece("Total Fat Bg", y: 0.34),
        piece("10%", y: 0.35, x: 0.82, width: 0.13),
        piece("Saturated Fat 0.5g", y: 0.381),
        piece("3%", y: 0.386, x: 0.85, width: 0.09),
        piece("Trans Fat 0g", y: 0.415),
        piece("Cholesterol 0mg", y: 0.456),
        piece("Sodium 260mg", y: 0.493),
        piece("11%", y: 0.506, x: 0.85, width: 0.1),
        piece("Total Carbohydrate 17g", y: 0.534),
        piece("6%", y: 0.541, x: 0.87, width: 0.09),
        piece("Dietary Fiber 2g", y: 0.571),
        piece("Total Sugars 0g", y: 0.608),
        piece("Includes 0g Added Sugars", y: 0.653),
        piece("Protein 2g", y: 0.687),
        piece("Calcium 20mg", y: 0.79),
        piece("a serving of food contributes to a daily diet. 2,000", y: 0.944)
    ]

    @Test func readsAFullPanel() throws {
        let label = try #require(NutritionLabelParser.parse(chips))
        #expect(label.nutrition.calories == 150)
        #expect(label.nutrition.fat == 8)
        #expect(label.nutrition.carbohydrates == 17)
        #expect(label.nutrition.protein == 2)
        #expect(label.nutrition.sodiumMilligrams == 260)
        #expect(label.nutrition.fiber == 2)
        #expect(label.nutrition.sugars == 0)
        #expect(label.amountGrams == 28)
        #expect(label.servingsPerContainer == 9)
        #expect(label.isComplete)
    }

    @Test func ignoresPrintNextToThePanel() throws {
        // Marketing beside the panel: nothing here may turn into a nutrient.
        let label = try #require(NutritionLabelParser.parse(chips + [
            piece("HOLE", y: 0.34, x: 0.0, width: 0.02),
            piece("/60 calories, 12g of whole", y: 0.4, x: 0.6, width: 0.3),
            piece("pins, and 3g d protein per", y: 0.43, x: 0.6, width: 0.3)
        ]))
        #expect(label.nutrition.calories == 150)
        #expect(label.nutrition.protein == 2)
    }

    @Test func correctsCommonMisreads() throws {
        let label = try #require(NutritionLabelParser.parse([
            piece("Calories 140", y: 0.1),
            piece("Total Fat 15gg", y: 0.2),
            piece("Total Carb. lg", y: 0.3),
            piece("Profein Og", y: 0.4)
        ]))
        #expect(label.nutrition.fat == 15)
        #expect(label.nutrition.carbohydrates == 1)
        #expect(label.nutrition.protein == 0)
        #expect(label.unread.isEmpty)
    }

    @Test func readsAnAmountInItsOwnColumn() throws {
        let label = try #require(NutritionLabelParser.parse([
            piece("Calories", y: 0.1, width: 0.2),
            piece("160", y: 0.1, x: 0.5, width: 0.1),
            piece("Total Fat", y: 0.2, width: 0.2),
            piece("1.5g", y: 0.2, x: 0.5, width: 0.1),
            piece("Total Carb.", y: 0.3, width: 0.2),
            piece("31g", y: 0.3, x: 0.5, width: 0.1),
            piece("Protein", y: 0.4, width: 0.2),
            piece("5g", y: 0.4, x: 0.5, width: 0.1)
        ]))
        #expect(label.nutrition.fat == 1.5)
        #expect(label.nutrition.carbohydrates == 31)
        #expect(label.nutrition.protein == 5)
    }

    @Test func readsALabelWrittenAsOneParagraph() throws {
        let label = try #require(NutritionLabelParser.parse([
            piece("Amount per serving: Calories 190, Total Fat 7g (9% DV), Saturated Fat 1g (4% DV), Sodium 140mg (6% DV), Total Carb. 29g (11% DV), Protein 3g", y: 0.5, width: 0.9)
        ]))
        #expect(label.nutrition.calories == 190)
        #expect(label.nutrition.fat == 7)
        #expect(label.nutrition.carbohydrates == 29)
        #expect(label.nutrition.protein == 3)
        #expect(label.nutrition.sodiumMilligrams == 140)
    }

    @Test func prefersTheServingColumnOnAEuropeanPanel() throws {
        let label = try #require(NutritionLabelParser.parse([
            piece("Per 100g", y: 0.1, x: 0.4, width: 0.15),
            piece("Per serving", y: 0.1, x: 0.7, width: 0.15),
            piece("Energy 2000 kJ / 478 kcal", y: 0.2, width: 0.3),
            piece("478 kcal", y: 0.2, x: 0.4, width: 0.15),
            piece("143 kcal", y: 0.2, x: 0.7, width: 0.15),
            piece("Fat", y: 0.3, width: 0.1),
            piece("20g", y: 0.3, x: 0.4, width: 0.15),
            piece("6g", y: 0.3, x: 0.7, width: 0.15),
            piece("Carbohydrate", y: 0.4, width: 0.2),
            piece("60g", y: 0.4, x: 0.4, width: 0.15),
            piece("18g", y: 0.4, x: 0.7, width: 0.15),
            piece("Protein", y: 0.5, width: 0.1),
            piece("10g", y: 0.5, x: 0.4, width: 0.15),
            piece("3g", y: 0.5, x: 0.7, width: 0.15)
        ]))
        #expect(label.nutrition.fat == 6)
        #expect(label.nutrition.protein == 3)
        #expect(label.amountGrams != 100)
    }

    @Test func aPanelOnlyGivingPer100gSaysSo() throws {
        let label = try #require(NutritionLabelParser.parse([
            piece("Nutrition per 100g", y: 0.1),
            piece("Energy 523 kcal", y: 0.2),
            piece("Fat 31.8g", y: 0.3),
            piece("Carbohydrate 49.6g", y: 0.4),
            piece("Protein 5.4g", y: 0.5)
        ]))
        #expect(label.nutrition.calories == 523)
        #expect(label.amountGrams == 100)
    }

    @Test func aMissingAmountIsFlaggedRatherThanZero() throws {
        let label = try #require(NutritionLabelParser.parse([
            piece("Calories 160", y: 0.1),
            piece("Total Fat 2g", y: 0.2),
            piece("Total Carbohydrate 30g", y: 0.3),
            piece("Protein", y: 0.4)
        ]))
        #expect(label.unread == ["Protein"])
        #expect(!label.isComplete)
    }

    @Test func numbersThatCantBeRightFailTheCheck() throws {
        let label = try #require(NutritionLabelParser.parse([
            piece("Calories 70", y: 0.1),
            piece("Total Fat 1.5g", y: 0.2),
            piece("Total Carbohydrate 120g", y: 0.3),
            piece("Protein 1g", y: 0.4)
        ]))
        // 120 g of carbs read for 12 g: dropping the digit makes it add up.
        #expect(label.nutrition.carbohydrates == 12)
        #expect(label.addsUp)
    }

    @Test func aPackageMentioningNutrientsIsNotAPanel() {
        #expect(NutritionLabelParser.parse([piece("High in protein", y: 0.2), piece("LAY'S", y: 0.1)]) == nil)
        #expect(NutritionLabelParser.parse([]) == nil)
    }

    @Test func servingWeights() {
        #expect(NutritionLabelParser.grams(in: "1 oz (28g/About 15 chips)") == 28)
        #expect(NutritionLabelParser.grams(in: "1 Slice (45g/1.6oz)") == 45)
        #expect(NutritionLabelParser.grams(in: "2 tbsp (30 q)") == 30)
        #expect(NutritionLabelParser.grams(in: "8 fl oz (240 mL)") == 240)
        #expect(abs((NutritionLabelParser.grams(in: "1 oz") ?? 0) - 28.35) < 0.01)
        #expect(NutritionLabelParser.grams(in: "1 bar") == nil)
    }
}

struct PackageMatcherTests {
    private func product(_ name: String, brand: String? = nil, popularity: Int = 0) -> FoodProduct {
        FoodProduct(id: name + (brand ?? ""), name: name, brand: brand, serving: "1 oz", nutrition: Nutrition(calories: 160), source: .openFoodFacts, popularity: popularity)
    }

    private let bag = [
        piece("LAY'S", y: 0.1, height: 0.15),
        piece("Classic", y: 0.3, height: 0.08),
        piece("POTATO CHIPS", y: 0.4, height: 0.06),
        piece("NET WT 8 OZ (226.8g)", y: 0.9, height: 0.02)
    ]

    @Test func searchesForTheBiggestPrintFirst() {
        let words = PackageMatcher.searchWords(in: bag).map(\.word)
        #expect(words.first == "lays")
        #expect(PackageMatcher.queries(for: PackageMatcher.searchWords(in: bag)).first == "\"lays\" AND \"chips\" AND \"potato\"")
    }

    @Test func aBrandOnThePackageBeatsAPlainFood() {
        let ranked = PackageMatcher.rank([
            product("Potato Chips"),
            product("Classic Potato Chips", brand: "Great Value"),
            product("Classic Potato Chips", brand: "Lay's")
        ], texts: bag)
        #expect(ranked.first?.product.brand == "Lay's")
    }

    @Test func aProductWithWordsNotOnThePackageFitsWorse() {
        let words = Set(PackageMatcher.searchWords(in: bag).map(\.word))
        #expect(PackageMatcher.coverage(of: product("Classic Potato Chips", brand: "Lay's"), seen: words) == 1)
        #expect(PackageMatcher.coverage(of: product("Barbecue Potato Chips", brand: "Lay's"), seen: words) < 1)
    }

    @Test func packagingWordsAreNotSearchedFor() {
        let queries = PackageMatcher.queries(for: PackageMatcher.searchWords(in: [piece("NET WT 8 OZ", y: 0.1), piece("Gluten Free", y: 0.2)]))
        #expect(queries.isEmpty)
    }
}

private struct Catalogue: OnlineFoodSource {
    var products: [String: FoodProduct] = [:]
    func search(_ query: String) async throws -> [FoodProduct] { [] }
    func product(barcode: String) async throws -> FoodProduct? { products[barcode] }
}

struct PhotoRoutingTests {
    private let chips = FoodProduct(id: "1", name: "Classic Potato Chips", brand: "Lay's", serving: "1 oz", nutrition: Nutrition(calories: 160), source: .openFoodFacts)
    private let panel = [
        piece("Calories 160", y: 0.1),
        piece("Total Fat 10g", y: 0.2),
        piece("Total Carbohydrate 15g", y: 0.3),
        piece("Protein 2g", y: 0.4)
    ]

    private func repository(_ products: [String: FoodProduct] = [:]) -> FoodRepository {
        FoodRepository(bundled: nil, local: nil, online: Catalogue(products: products))
    }

    @Test func aKnownBarcodeBeatsThePanelBesideIt() async {
        let printed = PrintedText(barcodes: ["028400040112"], texts: panel)
        #expect(await PhotoIdentifier.finding(for: printed, repository: repository(["028400040112": chips])) == .product(chips))
    }

    @Test func anUnknownBarcodeFallsBackToThePanel() async {
        let printed = PrintedText(barcodes: ["999"], texts: panel)
        guard case let .label(label) = await PhotoIdentifier.finding(for: printed, repository: repository()) else {
            Issue.record("Expected a label")
            return
        }
        #expect(label.nutrition.calories == 160)
    }

    @Test func nothingPrintedIsAMeal() async {
        #expect(await PhotoIdentifier.finding(for: PrintedText(), repository: repository()) == .meal)
    }

    @Test func incidentalTextIsStillAMeal() async {
        let printed = PrintedText(texts: [piece("Thank you for dining with us", y: 0.9, height: 0.01)])
        #expect(await PhotoIdentifier.finding(for: printed, repository: repository()) == .meal)
    }

    @Test func aLabelBecomesAProductToLog() throws {
        let label = try #require(NutritionLabelParser.parse(panel + [piece("Serving size 1 oz (28g)", y: 0.05)]))
        let product = FoodProduct(label: label, name: "Chips")
        #expect(product.name == "Chips")
        #expect(product.serving == "1 oz (28g)")
        #expect(product.servingGrams == 28)
        #expect(product.nutrition == label.nutrition)
    }
}

/// Two photos of one package: the front, then the nutrition label.
struct PackagePhotoTests {
    private let chips = FoodProduct(id: "1", name: "Classic Potato Chips", brand: "Lay's", serving: "1 oz", nutrition: Nutrition(calories: 160), source: .openFoodFacts)
    private let panel = PrintedText(texts: [
        piece("Calories 160", y: 0.1),
        piece("Total Fat 10g", y: 0.2),
        piece("Total Carbohydrate 15g", y: 0.3),
        piece("Protein 2g", y: 0.4)
    ])
    private let front = FrontReading(printed: PrintedText(texts: [piece("Lay's", y: 0.3, height: 0.2)]), seenName: "Lay's Classic")

    private func repository(_ products: [String: FoodProduct] = [:]) -> FoodRepository {
        FoodRepository(bundled: nil, local: nil, online: Catalogue(products: products))
    }

    @Test func theLabelGivesTheNumbersAndTheFrontTheName() async {
        guard case let .label(label, name, _) = await PhotoIdentifier.package(front: front, label: panel, repository: repository()) else {
            Issue.record("Expected a label")
            return
        }
        #expect(label.nutrition.calories == 160)
        #expect(name == "Lay's Classic")
    }

    @Test func aBarcodeOnTheBackNamesTheProduct() async {
        var back = panel
        back.barcodes = ["028400040112"]
        let finding = await PhotoIdentifier.package(front: front, label: back, repository: repository(["028400040112": chips]))
        #expect(finding == .product(chips))
    }

    @Test func photosTakenTheWrongWayRoundStillFindThePanel() async {
        let swapped = FrontReading(printed: panel, seenName: nil)
        guard case let .label(_, name, _) = await PhotoIdentifier.package(front: swapped, label: front.printed, repository: repository()) else {
            Issue.record("Expected a label")
            return
        }
        #expect(name.isEmpty)
    }

    @Test func nothingReadableSaysSo() async {
        let blank = FrontReading(printed: PrintedText(), seenName: nil)
        #expect(await PhotoIdentifier.package(front: blank, label: PrintedText(), repository: repository()) == .unread)
    }

    @Test func aBrandIsNotRepeatedInTheName() {
        #expect(chips.fullName == "Lay's Classic Potato Chips")
        var named = chips
        named.name = "Lay's Classic"
        #expect(named.fullName == "Lay's Classic")
    }
}

struct PackageGateTests {
    private func product(_ name: String, brand: String?) -> FoodProduct {
        FoodProduct(id: name, name: name, brand: brand, serving: "1 oz", nutrition: Nutrition(calories: 160), source: .openFoodFacts)
    }

    @Test func aPackageNeedsItsBrandOnShow() {
        let texts = [piece("Potato Chips", y: 0.1)]
        #expect(PackageMatcher.choices([product("Potato Chips", brand: "Lay's")], texts: texts).isEmpty)
        #expect(PackageMatcher.choices([product("Potato Chips", brand: nil)], texts: texts).isEmpty)
    }

    @Test func aBrandAndNameOnShowAreAPackage() {
        let texts = [piece("LAY'S", y: 0.1), piece("Potato Chips", y: 0.3)]
        #expect(PackageMatcher.choices([product("Potato Chips", brand: "Lay's")], texts: texts).first?.brand == "Lay's")
    }

    @Test func aNameRecognisedFromALogoCountsAsPrint() {
        let texts = [piece("Original Taste", y: 0.5)] + PackageMatcher.namedPieces(brand: "Coca-Cola", product: "Original Taste")
        let words = PackageMatcher.searchWords(in: texts).map(\.word)
        #expect(words.prefix(2).contains("coca"))
        #expect(words.prefix(2).contains("cola"))
    }

    @Test func spellingIsCorrectedFromTheDatabase() {
        let vocabulary = FoodVocabulary(entries: [(word: "starkist", frequency: 500), (word: "tuna", frequency: 9000)])
        let words = PackageMatcher.searchWords(in: [piece("STARKISTA", y: 0.1), piece("TUNA", y: 0.2)], vocabulary: vocabulary).map(\.word)
        #expect(words.contains("starkist"))
    }
}
