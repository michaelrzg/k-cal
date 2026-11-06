//
//  AddFoodView.swift
//  k-cal
//
//  The Add tab: the ways in at the top, then recent foods, and search results as the user types.
//

import SwiftData
import SwiftUI

struct AddFoodView: View {
    private static let recentLimit = 8

    @Environment(AddFoodFlow.self) private var flow
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]
    @Query(sort: [SortDescriptor(\Search.day, order: .reverse)]) private var history: [Search]
    @State private var query = ""
    @State private var results: [FoodProduct] = []
    @State private var isSearchActive = false
    @State private var isSearching = false
    @State private var hasSubmitted = false
    @State private var failure: String?

    private let repository = FoodRepository.shared

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var matchingCustomFoods: [CustomFood] {
        trimmedQuery.isEmpty ? [] : customFoods.filter { $0.matches(trimmedQuery) }
    }

    /// Everything logged before, for putting familiar foods first.
    private var familiarNames: Set<String> {
        Set(history.map { $0.food.name.lowercased() })
    }

    private var recentFoods: [Food] {
        var seen = Set<String>()
        return history.map(\.food).filter { seen.insert($0.name).inserted }.prefix(Self.recentLimit).map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    idle
                } else {
                    searchResults
                }
            }
            .themedList()
            .navigationTitle("Add Food")
            .searchable(text: $query, isPresented: $isSearchActive, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search over 1 million foods")
            .onSubmit(of: .search) { hasSubmitted = true; Task { await search(allowOnline: true) } }
            .task(id: trimmedQuery) {
                hasSubmitted = false
                failure = nil
                guard !trimmedQuery.isEmpty else { results = []; return }
                // As the user types, only the device is searched: online is for when they press Search.
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await search(allowOnline: false)
            }
            .onChange(of: flow.searchRequests) { activateSearchIfRequested() }
            .onChange(of: flow.savedCount) {
                query = ""
                isSearchActive = false
            }
            .task { activateSearchIfRequested() }
        }
    }

    /// Covers a request made before this tab first appeared too, as when a widget opens the app. The field
    /// can't take focus until the tab is on screen.
    private func activateSearchIfRequested() {
        guard flow.consumePendingSearch() else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            isSearchActive = true
        }
    }

    @ViewBuilder
    private var idle: some View {
        Section {
            HStack(spacing: 10) {
                ActionTile(title: "Scan", symbol: "barcode.viewfinder") { flow.start(.scan) }
                ActionTile(title: "Snap", symbol: "camera") { flow.start(.snapMeal) }
                ActionTile(title: "My Foods", symbol: "square.and.pencil") { flow.start(.myFoods) }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        if !recentFoods.isEmpty {
            Section("Recent") {
                ForEach(recentFoods) { food in
                    Button { flow.logAgain(food) } label: { RecentFoodRow(food: food) }
                        .buttonStyle(.plain)
                }
            }
            .listRowBackground(Theme.card)
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if !matchingCustomFoods.isEmpty {
            Section("My Foods") {
                ForEach(matchingCustomFoods) { food in
                    FoodProductRow(product: food.product) { flow.review(food.product) }
                }
            }
            .listRowBackground(Theme.card)
        }
        if !results.isEmpty {
            Section {
                ForEach(results) { product in
                    FoodProductRow(product: product) { flow.review(product) }
                }
            } footer: {
                Text("Data from USDA FoodData Central, Open Food Facts, Health Canada and MenuStat. Restaurant items show the year of their menu, and may have changed since.")
            }
            .listRowBackground(Theme.card)
        } else if matchingCustomFoods.isEmpty, !isSearching {
            Section {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text(failure ?? (hasSubmitted ? "Try a different name, or add it to My Foods." : "Press Search to look online too."))
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    private func search(allowOnline: Bool) async {
        let term = trimmedQuery
        guard !term.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await repository.search(term, online: allowOnline, familiar: familiarNames)
            guard term == trimmedQuery else { return }
            results = found
            failure = nil
        } catch {
            guard term == trimmedQuery else { return }
            results = []
            failure = error.localizedDescription
        }
    }
}

private struct RecentFoodRow: View {
    let food: Food

    var body: some View {
        HStack(spacing: 12) {
            FoodThumbnail(url: URL(string: food.url))
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).lineLimit(1)
                Text(food.brand?.isEmpty == false ? food.brand! : "Logged before")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(food.calories_per_serving) cal")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
