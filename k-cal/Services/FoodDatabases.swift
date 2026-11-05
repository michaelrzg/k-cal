//
//  FoodDatabases.swift
//  k-cal
//
//  The foods stored on the device: the read-only database in the app bundle, built by
//  tools/food_database/build.py, and a writable one for everything fetched since.
//

import Foundation

private enum FoodSQL {
    /// An FTS5 query that needs every word, each as a prefix. Words are letters and digits only.
    static func match(_ query: String) -> String? {
        let words = FoodText.words(in: query)
        return words.isEmpty ? nil : words.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    static func source(_ value: Int?) -> FoodProduct.Source {
        switch value {
        case 2: .openFoodFacts
        case 3: .canadianNutrientFile
        default: .usda
        }
    }

    /// Stored amounts are integers of a tenth of a unit. Columns must start at `first`, in Nutrition order.
    static func nutrition(_ row: OpaquePointer, first: Int32) -> Nutrition {
        func amount(_ offset: Int32) -> Double {
            Double(SQLite.integer(row, first + offset) ?? 0) / 10
        }
        return Nutrition(
            calories: amount(0),
            protein: amount(1),
            carbohydrates: amount(2),
            fat: amount(3),
            sodiumMilligrams: amount(4),
            sugars: amount(5),
            fiber: amount(6)
        )
    }
}

/// The database in the app bundle.
final class BundledFoodDatabase: @unchecked Sendable {
    private static let columns = """
    f.id, f.name, b.name, f.barcode, f.serving, f.source, f.calories, f.protein, f.carbohydrates, f.fat, f.sodium, f.sugars, f.fiber
    """
    private static let searchLimit = 400

    private let database: SQLite
    private let lock = NSLock()

    init(url: URL) throws {
        database = try SQLite(url: url, readOnly: true, immutable: true)
    }

    func search(_ query: String) throws -> [FoodProduct] {
        guard let match = FoodSQL.match(query) else { return [] }
        lock.lock()
        defer { lock.unlock() }
        // bm25 favours short text, which suits food names: "Banana" before "Banana Nut Granola".
        return try database.query("""
        SELECT \(Self.columns) FROM food_search s
        JOIN food f ON f.id = s.rowid LEFT JOIN brand b ON b.id = f.brand
        WHERE food_search MATCH ? ORDER BY bm25(food_search) LIMIT \(Self.searchLimit)
        """, [match], row: Self.product)
    }

    func product(barcode: String) throws -> FoodProduct? {
        guard let code = Barcode.canonical(barcode).flatMap(Int.init) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return try database.query("""
        SELECT \(Self.columns) FROM food f LEFT JOIN brand b ON b.id = f.brand WHERE f.barcode = ? LIMIT 1
        """, [code], row: Self.product).first
    }

    /// How many foods shipped with the app.
    func count() throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        return try database.query("SELECT count(*) FROM food") { SQLite.integer($0, 0) ?? 0 }.first ?? 0
    }

    /// When the data was exported, as a Unix time. Updates older than this are already included.
    func dataDate() throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        return try database.query("SELECT value FROM meta WHERE key = 'data_date'") {
            SQLite.integer($0, 0) ?? 0
        }.first ?? 0
    }

    private static func product(_ row: OpaquePointer) -> FoodProduct {
        let source = FoodSQL.source(SQLite.integer(row, 5))
        return FoodProduct(
            id: "food-\(SQLite.integer(row, 0) ?? 0)",
            name: SQLite.text(row, 1) ?? "",
            brand: SQLite.text(row, 2),
            barcode: SQLite.integer(row, 3).map(String.init),
            serving: SQLite.text(row, 4) ?? "",
            nutrition: FoodSQL.nutrition(row, first: 6),
            source: source
        )
    }
}

/// Foods fetched since the app was built. Keyed by barcode, so a newer copy of a product replaces the old one.
final class LocalFoodDatabase: @unchecked Sendable {
    private static let columns = """
    barcode, name, brand, serving, image, ingredients, calories, protein, carbohydrates, fat, sodium, sugars, fiber
    """
    private static let searchLimit = 100

    private let database: SQLite
    private let lock = NSLock()

    init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        database = try SQLite(url: url, readOnly: false)
        try database.execute("""
        PRAGMA journal_mode = WAL;
        CREATE TABLE IF NOT EXISTS food(barcode INTEGER PRIMARY KEY, name TEXT NOT NULL, brand TEXT, serving TEXT NOT NULL,
            image TEXT, ingredients TEXT, calories INTEGER, protein INTEGER, carbohydrates INTEGER, fat INTEGER,
            sodium INTEGER, sugars INTEGER, fiber INTEGER);
        CREATE VIRTUAL TABLE IF NOT EXISTS food_search USING fts5(text, tokenize="unicode61 remove_diacritics 2");
        """)
    }

    /// Foods that have no usable barcode are skipped: the barcode is what identifies them.
    func save(_ products: [FoodProduct]) throws {
        let saved = products.compactMap { product in
            product.barcode.flatMap(Barcode.canonical).flatMap(Int.init).map { (code: $0, product: product) }
        }
        guard !saved.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        try database.transaction {
            for (code, product) in saved {
                let nutrition = product.nutrition
                let amounts = [nutrition.calories, nutrition.protein, nutrition.carbohydrates, nutrition.fat,
                               nutrition.sodiumMilligrams, nutrition.sugars, nutrition.fiber]
                let values: [Any?] = [code, product.name, product.brand, product.serving, product.imageURL?.absoluteString, product.ingredients]
                    + amounts.map { Int(($0 * 10).rounded()) }
                try database.run("INSERT OR REPLACE INTO food(\(Self.columns)) VALUES (\(Array(repeating: "?", count: 13).joined(separator: ",")))", values)
                try database.run("DELETE FROM food_search WHERE rowid = ?", [code])
                try database.run("INSERT INTO food_search(rowid, text) VALUES (?, ?)", [code, "\(product.name) \(product.brand ?? "")"])
            }
        }
    }

    func search(_ query: String) throws -> [FoodProduct] {
        guard let match = FoodSQL.match(query) else { return [] }
        lock.lock()
        defer { lock.unlock() }
        return try database.query("""
        SELECT \(Self.columns.split(separator: ",").map { "f.\($0.trimmingCharacters(in: .whitespacesAndNewlines))" }.joined(separator: ", "))
        FROM food_search s JOIN food f ON f.barcode = s.rowid
        WHERE food_search MATCH ? ORDER BY bm25(food_search) LIMIT \(Self.searchLimit)
        """, [match], row: Self.product)
    }

    func product(barcode: String) throws -> FoodProduct? {
        guard let code = Barcode.canonical(barcode).flatMap(Int.init) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return try database.query("SELECT \(Self.columns) FROM food WHERE barcode = ?", [code], row: Self.product).first
    }

    func count() throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        return try database.query("SELECT count(*) FROM food") { SQLite.integer($0, 0) ?? 0 }.first ?? 0
    }

    private static func product(_ row: OpaquePointer) -> FoodProduct {
        let code = SQLite.integer(row, 0) ?? 0
        return FoodProduct(
            id: "local-\(code)",
            name: SQLite.text(row, 1) ?? "",
            brand: SQLite.text(row, 2),
            barcode: String(code),
            imageURL: SQLite.text(row, 4).flatMap(URL.init(string:)),
            serving: SQLite.text(row, 3) ?? "",
            ingredients: SQLite.text(row, 5),
            nutrition: FoodSQL.nutrition(row, first: 6),
            source: .openFoodFacts
        )
    }
}
