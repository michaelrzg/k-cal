//
//  SearchSheet.swift
//  k-cal
//
//  Created by Michael Rizig on 2/15/25.
//

import AVFoundation
import SwiftData
import SwiftUI

// Separate SearchSheet file (SearchSheet.swift)

struct SearchSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Query private var days: [Day]

    @Binding var searchText: String
    @Binding var searchResults: [FoodSearchItem]
    @Binding var isLoading: Bool
    @Binding var showErrorAlert: Bool
    @Binding var errorMessage: String?

    let dataFetcher: OpenFoodFactsFetcher

    init(searchText: Binding<String>, searchResults: Binding<[FoodSearchItem]>, isLoading: Binding<Bool>, showErrorAlert: Binding<Bool>, errorMessage: Binding<String?>) {
        self.dataFetcher = OpenFoodFactsFetcher()
        _searchText = searchText
        _searchResults = searchResults
        _isLoading = isLoading
        _showErrorAlert = showErrorAlert
        _errorMessage = errorMessage
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Form {
                Section {
                    TextField("Search for a food", text: $searchText)
                        .listRowBackground(Color("Background"))
                        .padding(.leading, 30)
                        .padding(10)
                        .background(
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("Foreground"))
                                    .listRowBackground(Color("Background"))

                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.blue)
                                    .padding(.leading, 5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .listRowBackground(Color("Background"))
                            }
                        )
                        .frame(height: 40)
                        .onSubmit {
                            performSearch(searchTerm: searchText)
                        }
                }

                var today: Day? {
                    let todayStart = Calendar.current.startOfDay(for: Date())
                    return days.first { Calendar.current.isDate($0.date, inSameDayAs: todayStart) }
                }

                if let today = today {
                    Text("Recent Foods")
                        .listRowBackground(Color("Background"))
                    ForEach(today.foods) { fooditem in
                        Meals_Item(food: fooditem)
                    }.listRowBackground(Color("Background"))
                }

                if !searchResults.isEmpty { // Check if searchResults is not empty
                    Text("Search Results")
                }

                List(searchResults) { item in
                    HStack {
                        AsyncImage(url: item.imageURL) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                        } placeholder: {
                            ProgressView()
                        }
                        VStack(alignment: .leading) {
                            Text(item.name).font(.headline)
                            Text(item.brand)
                        }
                        Spacer()
                        Button("Add") {
                            // addFoodFromSearch(item: item)  // You'll need to pass this function or handle it differently
                        }
                    }
                }

            }
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
        }
    }


    func performSearch(searchTerm: String) {
        isLoading = true

        let boostedSearchTerm = searchTerm

        dataFetcher.searchFood(for: boostedSearchTerm) { results, error in
            DispatchQueue.main.async {
                isLoading = false

                if let results = results {
                    searchResults = results
                    print("Search Results (Filtered): \(searchResults)")
                } else if let error = error {
                    errorMessage = error
                    showErrorAlert = true
                    print("Search Error: \(error)")
                }
            }
        }
    }


}

