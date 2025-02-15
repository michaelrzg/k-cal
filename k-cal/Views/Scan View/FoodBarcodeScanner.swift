import SwiftUI
import AVFoundation
import SwiftData

struct FoodBarcodeScanner: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var days: [Day]

    let dataFetcher: OpenFoodFactsFetcher
    @State private var isScanning = true
    @State private var barcode: String?
    @State private var food: Food?
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @State private var addFoodSheetOpen: Bool = false
    @State private var isLoading: Bool = false
    @State private var searchText: String = ""
    @State private var searchResults: [FoodSearchItem] = []

    @Binding var selectedTab: Int

    init(selectedTab: Binding<Int>) {
        self.dataFetcher = OpenFoodFactsFetcher()
        self._selectedTab = selectedTab
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)

            VStack {
                if isScanning {
                    BarcodeScannerView(barcode: $barcode, isScanning: $isScanning, dataFetcher: dataFetcher, context: context, day: fetchTodayDay(context: context))
                        .overlay(
                            Rectangle()
                                .frame(width: 40, height: 3)
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Rectangle()
                                .frame(width: 3, height: 40)
                                .foregroundColor(.white)
                        )
                }

                TextField("Search for food...", text: $searchText)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .onSubmit {
                        if !searchText.isEmpty {
                            performSearch(searchTerm: searchText)
                        } else {
                            searchResults = []
                        }
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
                            addFoodFromSearch(item: item)
                        }
                    }
                }

            } // End of VStack

            .alert(isPresented: $showErrorAlert) {
                Alert(title: Text("Error"), message: Text(errorMessage ?? "An error occurred."), dismissButton: .default(Text("OK")))
            }

            if isLoading {
                ZStack {
                    Color("Background")
                        .edgesIgnoringSafeArea(.all)
                        .opacity(0.9)

                    VStack {
                        ProgressView("Fetching food data...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
            }
        } // End of ZStack
        .onAppear {
            startScanningIfNeeded()
        }
        .onChange(of: barcode) { newValue in
            if let barcode = newValue {
                print("Barcode scanned: \(barcode)")
                isLoading = true

                dataFetcher.fetchFoodData(forBarcode: barcode, context: context, day: fetchTodayDay(context: context)) { fetchedFood, error in
                    DispatchQueue.main.async {
                        isLoading = false
                        if let fetchedFood = fetchedFood {
                            food = fetchedFood
                            addFoodSheetOpen = true
                            isScanning = false
                        } else if let error = error {
                            errorMessage = error
                            showErrorAlert = true
                            isScanning = true
                            self.barcode = nil
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $addFoodSheetOpen) {
            if let food = food {
                AddFoodSheet(food: food, selectedTab: $selectedTab)
                    .onDisappear {
                        isScanning = true
                        barcode = nil
                        dismiss()
                    }
            }
        }
    }

    func performSearch(searchTerm: String) {
        isLoading = true // Show loading indicator

        let boostedSearchTerm = searchTerm// Boost exact matches in product_name

        dataFetcher.searchFood(for: boostedSearchTerm) { results, error in
            DispatchQueue.main.async { // Update UI on the main thread
                isLoading = false // Hide loading indicator

                if let results = results {
                    
                    searchResults = results // Use the filtered results

                    print("Search Results (Filtered): \(searchResults)") // Print the filtered results

                } else if let error = error {
                    errorMessage = error
                    showErrorAlert = true
                    print("Search Error: \(error)")
                }
            }
        }
    }

    func addFoodFromSearch(item: FoodSearchItem) {
        isLoading = true
        dataFetcher.fetchFoodData(forBarcode: item.barcode, context: context, day: fetchTodayDay(context: context)) { fetchedFood, error in
            DispatchQueue.main.async {
                isLoading = false
                if let fetchedFood = fetchedFood {
                    food = fetchedFood
                    addFoodSheetOpen = true
                    isScanning = false
                } else if let error = error {
                    errorMessage = error
                    showErrorAlert = true
                    isScanning = true
                    barcode = nil
                }
            }
        }
    }


    func startScanningIfNeeded() {
        if isScanning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isScanning = true
            }
        }
    }

    func fetchTodayDay(context: ModelContext) -> Day {
        let todayStart = Calendar.current.startOfDay(for: Date())

        let fetchDescriptor = FetchDescriptor<Day>(
            predicate: #Predicate { $0.date == todayStart }
        )

        do {
            if let existingDay = try context.fetch(fetchDescriptor).first {
                return existingDay
            } else {
                let newDay = Day(date: todayStart)
                context.insert(newDay)
                try context.save()
                return newDay
            }
        } catch {
            fatalError("Error fetching or creating today's Day: \(error)")
        }
    }
}
