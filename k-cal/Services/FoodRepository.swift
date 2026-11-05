//
//  FoodRepository.swift
//  k-cal
//
//  The one place the app asks for food data. Everything is answered on the device if it can be. Only a
//  miss goes online, and what comes back is kept, so each food is fetched once.
//

import Foundation

/// A live source for foods the device doesn't have.
protocol OnlineFoodSource: Sendable {
    func search(_ query: String) async throws -> [FoodProduct]
    func product(barcode: String) async throws -> FoodProduct?
}

enum FoodRepositoryError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "That food isn't on your phone, and it couldn't be looked up online. Check your connection and try again."
    }
}

final class FoodRepository: Sendable {
    /// With fewer matches than this, a search also asks online.
    private static let enoughResults = 10
    private static let resultLimit = 40

    static let shared: FoodRepository = {
        let local = URL.applicationSupportDirectory.appending(path: "foods-local.sqlite")
        return FoodRepository(
            bundled: Bundle.main.url(forResource: "foods", withExtension: "sqlite").flatMap { try? BundledFoodDatabase(url: $0) },
            local: try? LocalFoodDatabase(url: local),
            online: OpenFoodFactsClient()
        )
    }()

    /// Nil only if a database can't be opened, in which case lookups just go online.
    let bundled: BundledFoodDatabase?
    let local: LocalFoodDatabase?
    private let online: any OnlineFoodSource

    init(bundled: BundledFoodDatabase?, local: LocalFoodDatabase?, online: any OnlineFoodSource) {
        self.bundled = bundled
        self.local = local
        self.online = online
    }

    func search(_ query: String) async throws -> [FoodProduct] {
        let (bundled, local) = (bundled, local)
        // On a background thread: a broad search takes tens of milliseconds.
        let onDevice = await Task.detached(priority: .userInitiated) {
            let found = (try? local?.search(query)) ?? []
            return found + ((try? bundled?.search(query)) ?? [])
        }.value
        var ranked = Self.rank(onDevice, query: query)
        guard ranked.count < Self.enoughResults else { return Array(ranked.prefix(Self.resultLimit)) }

        do {
            let fetched = try await online.search(query)
            try? local?.save(fetched)
            ranked = Self.rank(ranked + fetched, query: query)
        } catch {
            // Offline with something to show is still a good answer.
            if ranked.isEmpty { throw FoodRepositoryError.unavailable }
        }
        return Array(ranked.prefix(Self.resultLimit))
    }

    /// - Returns: nil when nothing knows the barcode.
    func product(barcode: String) async throws -> FoodProduct? {
        if let found = try? local?.product(barcode: barcode) ?? bundled?.product(barcode: barcode) {
            return found
        }
        do {
            let found = try await online.product(barcode: barcode)
            if let found { try? local?.save([found]) }
            return found
        } catch {
            throw FoodRepositoryError.unavailable
        }
    }

    /// Removes duplicates, then puts the best name matches first. Among equals the shorter name wins, as
    /// "Banana, raw" is plainer than "Banana Nut Granola", and after that the original order.
    static func rank(_ products: [FoodProduct], query: String) -> [FoodProduct] {
        var seen = Set<String>()
        let unique = products.filter { product in
            let barcode = product.barcode.flatMap(Barcode.canonical)
            let keys = [barcode, "\(product.name)|\(product.brand ?? "")".lowercased()].compactMap { $0 }
            let isNew = keys.allSatisfy { !seen.contains($0) }
            seen.formUnion(keys)
            return isNew
        }
        return unique.enumerated()
            .sorted { lhs, rhs in
                let scores = (score(lhs.element, query: query), score(rhs.element, query: query))
                if scores.0 != scores.1 { return scores.0 > scores.1 }
                let lengths = (lhs.element.name.count, rhs.element.name.count)
                return lengths.0 == lengths.1 ? lhs.offset < rhs.offset : lengths.0 < lengths.1
            }
            .map(\.element)
    }

    private static func score(_ product: FoodProduct, query: String) -> Int {
        let name = product.name.lowercased()
        let phrase = query.lowercased().trimmingCharacters(in: .whitespaces)
        let terms = FoodText.words(in: query)
        let searchable = Set(FoodText.words(in: "\(product.name) \(product.brand ?? "")"))
        let words = FoodText.words(in: product.name)
        var score = 0
        // A plain food with no brand or barcode is what a plain search wants: USDA's "Bananas, raw".
        if product.brand == nil && product.barcode == nil { score += 9 }
        if name == phrase { score += 2 }
        if name.hasPrefix(phrase) { score += 4 }
        if name.contains(phrase) { score += 2 }
        // "Banana, raw" has the query as a whole word; "Bananamilk" only starts with it.
        // USDA's own names are often plural, so "banana" has to count as a match for "Bananas, raw".
        if terms.allSatisfy({ term in words.contains { $0 == term || $0 == term + "s" } }) { score += 8 }
        if terms.allSatisfy(searchable.contains) { score += 1 }
        return score
    }
}

enum FoodText {
    static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
}

enum FoodHTTP {
    enum Failure: Error, Equatable {
        case status(Int)
    }

    /// Open Food Facts asks clients to identify themselves.
    static let userAgent = "k-cal-iOS/1.0"

    static func request(_ url: URL, timeout: TimeInterval = 15) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    static func get(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request(url))
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw Failure.status(status)
        }
        return data
    }
}
