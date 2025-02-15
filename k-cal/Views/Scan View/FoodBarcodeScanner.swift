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
                AddFoodSheet(food: food, selectedTab: $selectedTab).onAppear(){
                    isSearchExpanded = false
                }
                    .onDisappear {
                        isScanning = true
                        
                        barcode = nil
                        dismiss()
                    }.interactiveDismissDisabled()
            }
        }
        .sheet(isPresented: $isSearchExpanded){
            ZStack(alignment: .bottom) {
                Form {
                    // Search Bar
                    Section {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                                .padding(.leading, 8)

                            TextField("Search for a food", text: $searchText)
                                .padding(10)
                                .background(Color.clear)
                                .onSubmit { performSearch(searchTerm: searchText) }
                        }
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color("Foreground")))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }
                    .listRowBackground(Color("Background"))

                    // Recent Foods
                    if let today = today {
                        Section(header: Text("Recent Foods").font(.headline).foregroundColor(.primary)) {
                            ForEach(today.foods) { fooditem in
                                Meals_Item(food: fooditem)
                                    .listRowBackground(Color("Background")).onTapGesture {
                                        
                                        food = fooditem
                                        addFoodSheetOpen = true
                                    }
                            }
                        }
                    }

                    // Search Results
                    if !searchResults.isEmpty {
                        Section(header: Text("Search Results").font(.headline).foregroundColor(.primary)) {
                            ForEach(searchResults) { item in
                                HStack(spacing: 12) {
                                    AsyncImage(url: item.imageURL) { image in
                                        image.resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray5))
                                            .frame(width: 50, height: 50)
                                            .overlay(ProgressView())
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text(item.brand)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        addFoodFromSearch(item: item)
                                    } label: {
                                        Text("Add")
                                            .font(.system(size: 14, weight: .semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .padding(.vertical, 6)
                                .listRowBackground(Color("Background"))
                            }
                        }
                    }
                    
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(Color.clear)

                .alert(isPresented: $showErrorAlert) {
                    Alert(title: Text("Error"), message: Text(errorMessage ?? "An error occurred."), dismissButton: .default(Text("OK")))
                }

                // Loading Indicator
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                        VStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Fetching food data...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)).opacity(0.8))
                    }
                }
            }

            // Computed Property for Today's Date
            var today: Day? {
                let todayStart = Calendar.current.startOfDay(for: Date())
                return days.first { Calendar.current.isDate($0.date, inSameDayAs: todayStart) }
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
