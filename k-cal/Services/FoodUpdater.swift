//
//  FoodUpdater.swift
//  k-cal
//
//  Fetches new and changed North American products into the local database, from the daily export files
//  Open Food Facts publishes. They're static downloads, so they need no key and have no request limit, but
//  each is 25-45 MB. Progress is saved after every file, so an interrupted update carries on where it stopped.
//

import Foundation
import Network
import Observation

/// Which export files still need applying.
enum FoodUpdatePlan {
    struct Export: Equatable {
        let file: String
        /// The Unix time this file runs up to.
        let end: Int
    }

    /// - Parameter after: the time everything is already applied up to.
    /// - Returns: the files to apply, oldest first.
    static func pending(index: String, after: Int) -> [Export] {
        index.split(whereSeparator: \.isNewline)
            .compactMap { line -> Export? in
                let file = line.trimmingCharacters(in: .whitespaces)
                let parts = file.replacingOccurrences(of: ".json.gz", with: "").split(separator: "_")
                guard file.hasPrefix("openfoodfacts_products_"), parts.count == 4, let end = Int(parts[3]) else { return nil }
                return Export(file: file, end: end)
            }
            .filter { $0.end > after }
            .sorted { $0.end < $1.end }
    }
}

@MainActor
@Observable
final class FoodUpdater {
    static let shared = FoodUpdater(repository: .shared)
    static let autoUpdateKey = "foodAutoUpdate"

    private static let baseURL = URL(string: "https://static.openfoodfacts.org/data/delta/")!
    private static let throughKey = "foodUpdateThrough"
    private static let checkedKey = "foodUpdateChecked"
    private static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let batchSize = 500

    private(set) var isUpdating = false
    private(set) var status: String?
    private(set) var lastChecked: Date?
    private(set) var failure: String?
    private(set) var downloadedFoods = 0
    private(set) var bundledFoods = 0

    private let repository: FoodRepository
    private var task: Task<Void, Never>?

    init(repository: FoodRepository) {
        self.repository = repository
        lastChecked = UserDefaults.standard.object(forKey: Self.checkedKey) as? Date
    }

    func refreshCounts() {
        bundledFoods = (try? repository.bundled?.count()) ?? 0
        downloadedFoods = (try? repository.local?.count()) ?? 0
    }

    /// Runs at launch: at most daily, and only on Wi-Fi or similar, given the size of the downloads.
    func updateIfDue() async {
        let automatic = UserDefaults.standard.object(forKey: Self.autoUpdateKey) as? Bool ?? true
        let due = lastChecked.map { Date().timeIntervalSince($0) >= Self.checkInterval } ?? true
        guard automatic, due, await Self.isOnUnmeteredNetwork() else { return }
        update()
    }

    func update() {
        guard !isUpdating else { return }
        isUpdating = true
        failure = nil
        status = "Checking for new foods..."
        task = Task {
            do {
                try await applyPendingExports()
                status = nil
            } catch is CancellationError {
                status = nil
            } catch URLError.cancelled {
                status = nil
            } catch {
                status = nil
                failure = "Couldn't finish updating. It will carry on from here next time."
            }
            isUpdating = false
            refreshCounts()
        }
    }

    func cancel() {
        task?.cancel()
    }

    private func applyPendingExports() async throws {
        let defaults = UserDefaults.standard
        let dataDate = (try? repository.bundled?.dataDate()) ?? 0
        var through = max(defaults.integer(forKey: Self.throughKey), dataDate)

        let indexURL = Self.baseURL.appending(path: "index.txt")
        let index = String(decoding: try await FoodHTTP.get(indexURL), as: UTF8.self)
        let exports = FoodUpdatePlan.pending(index: index, after: through)

        for (position, export) in exports.enumerated() {
            try Task.checkCancellation()
            status = "Downloading update \(position + 1) of \(exports.count)..."
            guard let local = repository.local else { return }
            try await Self.apply(export, to: local)
            through = export.end
            defaults.set(through, forKey: Self.throughKey)
            refreshCounts()
        }
        lastChecked = Date()
        defaults.set(lastChecked, forKey: Self.checkedKey)
    }

    private nonisolated static func apply(_ export: FoodUpdatePlan.Export, to local: LocalFoodDatabase) async throws {
        let url = baseURL.appending(path: export.file)
        let (file, response) = try await URLSession.shared.download(for: FoodHTTP.request(url, timeout: 120))
        defer { try? FileManager.default.removeItem(at: file) }
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw FoodHTTP.Failure.status(status)
        }
        try importExport(at: file, into: local)
    }

    /// Reads one export into the database, and returns how many foods it kept.
    @discardableResult
    nonisolated static func importExport(at file: URL, into local: LocalFoodDatabase) throws -> Int {
        // Most products are sold elsewhere, and parsing JSON costs far more than this search.
        let markers = [Data("en:united-states".utf8), Data("en:canada".utf8)]
        var batch: [FoodProduct] = []
        var kept = 0
        try GzipLineReader.forEachLine(in: file) { line in
            try Task.checkCancellation()
            guard markers.contains(where: { line.range(of: $0) != nil }),
                  let record = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let product = OpenFoodFactsClient.parseExport(record)
            else { return }
            batch.append(product)
            kept += 1
            if batch.count == batchSize {
                try local.save(batch)
                batch.removeAll(keepingCapacity: true)
            }
        }
        try local.save(batch)
        return kept
    }

    private static func isOnUnmeteredNetwork() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied && !path.isExpensive && !path.isConstrained)
            }
            monitor.start(queue: .global(qos: .utility))
        }
    }
}
