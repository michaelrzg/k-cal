import AVFoundation
import SwiftData
import SwiftUI

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
    @Binding private var isSearchExpanded: Bool
    @Binding var selectedTab: Int

    init(selectedTab: Binding<Int>, isSearchExpanded: Binding<Bool>) {
        dataFetcher = OpenFoodFactsFetcher()
        _selectedTab = selectedTab
        self._isSearchExpanded = isSearchExpanded
    }

    var body: some View {
        ZStack {
            ZStack {
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
                        ).ignoresSafeArea(.keyboard, edges: .bottom)
                }
                // Search block

                ZStack{
                    RoundedRectangle(cornerRadius: 25)
                                    .fill(Color("Foreground"))
                                    .frame(width:50,height: 50)
                    Image(systemName: "magnifyingglass")
                        .onTapGesture {
                            isSearchExpanded=true
                        }
                }
                .offset(y:300)// End of ZStack
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
        .sheet(isPresented: $isSearchExpanded){
            ZStack(alignment: .bottom) {
                Form {
                    Section {
                        TextField("Search for a food", text: $searchText).listRowBackground(Color("Background"))
                            .padding(.leading, 30) // Add leading padding for the icon
                            .padding(10) // Standard padding
                            .background(
                                ZStack(alignment: .leading) { // Use ZStack to layer icon and background
                                    RoundedRectangle(cornerRadius: 12) // Rounded background
                                        .fill(Color("Foreground"))
                                        .listRowBackground(Color("Background")) // Background color

                                    Image(systemName: "magnifyingglass") // Search icon
                                        .foregroundColor(.blue) // Icon color
                                        .padding(.leading, 5)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .listRowBackground(Color("Background"))
                                }
                            )
                            .frame(height: 40) // Fixed height for the TextField
                            // .padding(.horizontal) // Horizontal padding for the TextField
                            .onSubmit {
                                performSearch(searchTerm: searchText)
                            }
                    }
                    var today: Day? { // Computed property
                        let todayStart = Calendar.current.startOfDay(for: Date()) // Start of today
                        return days.first { Calendar.current.isDate($0.date, inSameDayAs: todayStart) }
                    }
                    if let today = today {
                        Text("Recent Foods").listRowBackground(Color("Background"))
                        ForEach(today.foods) { fooditem in
                            Meals_Item(food: fooditem)
                        }.listRowBackground(Color("Background"))
                    }

                    if searchResults.count != 0 {
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
                                addFoodFromSearch(item: item)
                            }
                        }
                    }

                }.scrollContentBackground(.hidden)
                    .listRowBackground(Color.clear)
            }

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
        }
    }
        }
    }

    func performSearch(searchTerm: String) {
        isLoading = true // Show loading indicator

        let boostedSearchTerm = searchTerm // Boost exact matches in product_name

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
