//
//  MyFoodsView.swift
//  k-cal
//
//  The user's custom foods: log one, add, edit or delete.
//

import SwiftData
import SwiftUI

struct MyFoodsView: View {
    let onPick: (FoodProduct) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomFood.name) private var foods: [CustomFood]
    @State private var searchText = ""
    @State private var editorFood: EditorTarget?

    private enum EditorTarget: Identifiable {
        case new
        case existing(CustomFood)

        var id: String {
            switch self {
            case .new: "new"
            case let .existing(food): "\(food.persistentModelID)"
            }
        }
    }

    private var visibleFoods: [CustomFood] {
        searchText.isEmpty ? foods : foods.filter { $0.matches(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleFoods) { food in
                    FoodProductRow(product: food.product) {
                        pick(food)
                    }
                    .swipeActions(edge: .leading) {
                        Button("Edit") { editorFood = .existing(food) }.tint(.blue)
                    }
                }
                .onDelete { offsets in
                    let shown = visibleFoods
                    offsets.forEach { context.delete(shown[$0]) }
                }
                .listRowBackground(Theme.card)
            }
            .overlay {
                if foods.isEmpty {
                    ContentUnavailableView {
                        Label("No Custom Foods", systemImage: "square.and.pencil")
                    } description: {
                        Text("Add foods that aren't in the search, like home recipes. Tap + to start.")
                    }
                } else if visibleFoods.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .themedList()
            .searchable(text: $searchText, prompt: "Search my foods")
            .navigationTitle("My Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorFood = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New food")
                }
            }
            .sheet(item: $editorFood) { target in
                switch target {
                case .new: CustomFoodEditor()
                case let .existing(food): CustomFoodEditor(food: food)
                }
            }
        }
    }

    private func pick(_ food: CustomFood) {
        onPick(food.product)
        dismiss()
    }
}
