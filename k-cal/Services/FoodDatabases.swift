//
//  FoodDatabases.swift
//  k-cal
//
//  The foods stored on the device: the read-only database in the app bundle, built by
//  tools/food_database/build.py, and a writable one for everything fetched since.
//

import Foundation

private enum FoodSQL {
    static func source(_ value: Int?) -> FoodProduct.Source {
        switch value {
        case 2: .openFoodFacts
        case 3: .canadianNutrientFile
        case 4: .restaurant
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
    f.id, f.name, b.name, f.barcode, f.serving, f.source, f.calories, f.protein, f.carbohydrates, f.fat, f.sodium, f.sugars, f.fiber, f.popularity
    """
    private static let bestMatchLimit = 300
    private static let popularLimit = 120
    private static let plainFoodLimit = 60
    /// A name counts for more than a brand, and either for more than a joined-up alias.
    private static let columnWeights = "8.0, 3.0, 3.0"

    private let database: SQLite
    private let lock = NSLock()

    init(url: URL) throws {
        database = try SQLite(url: url, readOnly: true, immutable: true)
    }

    /// The best text matches, plus two groups bm25 alone would miss for a broad word like "milk": the most
    /// popular products, and the plainest generic foods.
    func search(_ match: String) throws -> [FoodProduct] {
        lock.lock()
        defer { lock.unlock() }
        let best = try database.query("""
        SELECT \(Self.columns) FROM food_search s
        JOIN food f ON f.id = s.rowid LEFT JOIN brand b ON b.id = f.brand
        WHERE food_search MATCH ? ORDER BY bm25(food_search, \(Self.columnWeights)) LIMIT \(Self.bestMatchLimit)
        """, [match], row: Self.product)
        let popular = try database.query("""
        SELECT \(Self.columns) FROM food_search s
        JOIN food f ON f.id = s.rowid LEFT JOIN brand b ON b.id = f.brand
        WHERE food_search MATCH ? AND f.popularity > 0 ORDER BY f.popularity DESC LIMIT \(Self.popularLimit)
        """, [match], row: Self.product)
        let plain = try database.query("""
        SELECT \(Self.columns) FROM food_search s
        JOIN food f ON f.id = s.rowid LEFT JOIN brand b ON b.id = f.brand
        WHERE food_search MATCH ? AND f.brand IS NULL AND f.barcode IS NULL ORDER BY length(f.name) LIMIT \(Self.plainFoodLimit)
        """, [match], row: Self.product)
        return best + popular + plain
    }

    /// The words of the database, for spelling correction. Takes a moment, so it's loaded once, off the main thread.
    func loadVocabulary() throws -> FoodVocabulary {
        lock.lock()
        defer { lock.unlock() }
        return FoodVocabulary(entries: try database.query("SELECT word, frequency FROM vocabulary") {
            (SQLite.text($0, 0) ?? "", SQLite.integer($0, 1) ?? 0)
        })
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
            source: source,
            popularity: SQLite.integer(row, 13) ?? 0
        )
    }
}

/// Foods fetched since the app was built. Keyed by barcode, so a newer copy of a product replaces the old one.
final class LocalFoodDatabase: @unchecked Sendable {
    private static let columns = """
    barcode, name, brand, serving, image, ingredients, calories, protein, carbohydrates, fat, sodium, sugars, fiber
    """
    private static let searchLimit = 100
    private static let searchIndexVersion = 2

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
        """)
        try migrateSearchIndex()
    }

    /// Foods fetched under an older index are reindexed from the table, so they keep being found.
    private func migrateSearchIndex() throws {
        let version = try database.query("PRAGMA user_version") { SQLite.integer($0, 0) ?? 0 }.first ?? 0
        guard version < Self.searchIndexVersion else { return }
        try database.execute("""
        DROP TABLE IF EXISTS food_search;
        CREATE VIRTUAL TABLE food_search USING fts5(name, brand, alias, tokenize="porter unicode61 remove_diacritics 2");
        PRAGMA user_version = \(Self.searchIndexVersion);
        """)
        let rows = try database.query("SELECT barcode, name, brand FROM food") {
            (SQLite.integer($0, 0) ?? 0, SQLite.text($0, 1) ?? "", SQLite.text($0, 2))
        }
        try database.transaction {
            for row in rows { try index(code: row.0, name: row.1, brand: row.2) }
        }
    }

    private func index(code: Int, name: String, brand: String?) throws {
        try database.run("INSERT INTO food_search(rowid, name, brand, alias) VALUES (?, ?, ?, ?)", [
            code, FoodSearchText.normalized(name), FoodSearchText.normalized(brand ?? ""),
            FoodSearchText.aliases(name: name, brand: brand),
        ])
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
                try index(code: code, name: product.name, brand: product.brand)
            }
        }
    }

    func search(_ match: String) throws -> [FoodProduct] {
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
