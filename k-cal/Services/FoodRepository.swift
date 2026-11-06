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
    /// With fewer exact matches than this, a search also tries other spellings.
    private static let enoughStrictResults = 20
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
    private let vocabularyLoader = VocabularyLoader()

    init(bundled: BundledFoodDatabase?, local: LocalFoodDatabase?, online: any OnlineFoodSource) {
        self.bundled = bundled
        self.local = local
        self.online = online
    }

    /// Searches on the device, loosening only as far as it has to, then online if that still comes up thin.
    /// - Parameters:
    ///   - online: whether a thin result may go online. Off while typing, which would use up the limit.
    ///   - familiar: lowercased names of foods the user has logged, which rank higher.
    func search(_ query: String, online allowOnline: Bool = true, familiar: Set<String> = []) async throws -> [FoodProduct] {
        let (bundled, local) = (bundled, local)
        let vocabulary = await vocabulary()
        let plan = FoodSearchPlan(query: query, vocabulary: vocabulary)
        // On a background thread: a broad search takes tens of milliseconds.
        let onDevice = await Task.detached(priority: .userInitiated) {
            var found: [FoodProduct] = []
            func run(_ match: String?) {
                guard let match else { return }
                found += (try? local?.search(match)) ?? []
                found += (try? bundled?.search(match)) ?? []
            }
            run(plan.strict)
            if plan.hasCorrections || found.count < Self.enoughStrictResults { run(plan.corrected) }
            if found.count < Self.enoughResults { run(plan.partial) }
            return found
        }.value
        var ranked = FoodRanking.rank(onDevice, plan: plan, familiar: familiar)
        guard allowOnline, ranked.count < Self.enoughResults else { return Array(ranked.prefix(Self.resultLimit)) }

        do {
            let fetched = try await online.search(query)
            try? local?.save(fetched)
            ranked = FoodRanking.rank(ranked + fetched, plan: plan, familiar: familiar)
        } catch {
            // Offline with something to show is still a good answer.
            if ranked.isEmpty { throw FoodRepositoryError.unavailable }
        }
        return Array(ranked.prefix(Self.resultLimit))
    }

    /// Loaded on the first search rather than at launch, because reading the whole word list takes a moment.
    private func vocabulary() async -> FoodVocabulary? {
        await vocabularyLoader.value(loadingFrom: bundled)
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
}

/// Hands out one vocabulary, however many searches ask for it while it loads.
private actor VocabularyLoader {
    private var task: Task<FoodVocabulary?, Never>?

    func value(loadingFrom database: BundledFoodDatabase?) async -> FoodVocabulary? {
        if task == nil {
            task = Task.detached(priority: .userInitiated) { try? database?.loadVocabulary() }
        }
        return await task?.value
    }
}

enum FoodText {
    static func words(in text: String) -> [String] {
        FoodSearchText.words(in: text)
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
