import AVFoundation
import SwiftData
import SwiftUI

struct FoodBarcodeScanner: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var days: [Day]
    @Query(sort: [SortDescriptor(\Search.day, order: .reverse)]) var recentSearches: [Search]
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
    @State private var cardPosition: CardPosition = .bottom
    @State private var enterPressed: Bool = false
    @Binding private var isSearchExpanded: Bool
    @Binding var selectedTab: Int
    @FocusState private var isFocused: Bool
    let loadingPrompts = [
        "Hang tight... calculating deliciousness! 🍔",
        "Avocados are still expensive... but we’re loading! 🥑",
        "Summoning the food gods... 🍕",
        "Loading... don’t snack yet! 🍩",
        "Setting the table... almost there! 🍽",
        "Taco-bout patience! We’re loading... 🌮",
        "An apple a day... but this might take a second. 🍎",
        "Cheeseburgers don’t rush, neither should you! 🍔",
        "Healthy choices incoming... or are they? 🥗",
        "Barbecue takes time, so does this! 🍗",
        "Flipping pancakes... I mean, loading! 🥞",
        "Rolling up some data sushi... 🍣",
        "Popcorn’s not ready yet... loading! 🍿"
    ]

    init(selectedTab: Binding<Int>, isSearchExpanded: Binding<Bool>) {
        dataFetcher = OpenFoodFactsFetcher()
        _selectedTab = selectedTab
        self._isSearchExpanded = isSearchExpanded
    }

    var body: some View {
        GeometryReader{ geo in
            ScrollView{
                ZStack {
                    ZStack {
                        if isScanning {
                            BarcodeScannerView(barcode: $barcode, isScanning: $isScanning, dataFetcher: dataFetcher, context: context, day: fetchTodayDay(context: context))  .ignoresSafeArea(.keyboard, edges: .bottom)
                                .overlay(
                                    Rectangle()
                                        .frame(width: 40, height: 3)
                                        .foregroundColor(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).offset(y:-100)
                                )  .ignoresSafeArea(.keyboard, edges: .bottom)
                                .overlay(
                                    Rectangle()
                                        .frame(width: 3, height: 40)
                                        .foregroundColor(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).offset(y:-100)
                                ).ignoresSafeArea(.keyboard, edges: .bottom)
                        }
                        // Search block
                        if isLoading {
                            ZStack {
                                
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                    Text(loadingPrompts.randomElement() ?? "")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)).opacity(0.8))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            }.zIndex(3).offset(y:-100)
                        }
                        ZStack(alignment: .top){
                            
                            
                            SlideOverCard(position: $cardPosition) {
                                
                                VStack {
                                    
                                    Handle().padding(.top,10)  .ignoresSafeArea(.keyboard, edges: .bottom)
                                    
                                    HStack {
                                        
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.blue)
                                            .padding(.leading, 8).scaledToFill()  .ignoresSafeArea(.keyboard, edges: .bottom)
                                        
                                        TextField("Search for a food", text: $searchText)  .ignoresSafeArea(.keyboard, edges: .bottom).scrollDismissesKeyboard(.interactively)
                                        
                                            .background(Color.clear)
                                            .onSubmit {
                                                performSearch(searchTerm: searchText)
                                                enterPressed = true
                                            }
                                            .focused($isFocused)
                                    }  .ignoresSafeArea(.keyboard, edges: .bottom)
                                        .frame(height: 50)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color("Foreground")))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                    
                                        .listRowBackground(Color("Background")).padding(.horizontal,10)
                                   
                                    if !searchResults.isEmpty {
                                        ZStack{
                                            Color("Background")
                                            List{
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
                                                }.listRowBackground(Color("Background"))
                                            }.listRowBackground(Color("Foreground"))
                                                .scrollContentBackground(.hidden)
                                        }  .ignoresSafeArea(.keyboard, edges: .bottom)
                                    }
                                    else if searchText.isEmpty && !enterPressed {
                                        ZStack{
                                            Color("Background")
                                            List{
                                                Section(header: Text("Recent Searches").font(.headline).foregroundColor(.primary)) {
                                                    ForEach(recentSearches) { item in
                                                        HStack(spacing: 12) {
                                                            
                                                            if let url = URL(string: item.food.url){
                                                                AsyncImage(url: url) { image in
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
                                                            }
                                                            
                                                            VStack(alignment: .leading, spacing: 4) {
                                                                Text(item.food.name)
                                                                    .font(.headline)
                                                                    .foregroundColor(.primary)
                                                                
                                                          
                                                            }
                                                            
                                                            Spacer()
                                                            
                                                            Button {
                                                               food = item.food
                                                                addFoodSheetOpen = true
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
                                                }.listRowBackground(Color("Background"))
                                            }.listRowBackground(Color("Foreground"))
                                                .scrollContentBackground(.hidden)
                                        }  .ignoresSafeArea(.keyboard, edges: .bottom)
                                    }
                                    else if searchResults.isEmpty && enterPressed && !isLoading{
                                        List{
                                            Section{
                                                Text("No Results").frame(maxWidth: .infinity, maxHeight: .infinity)
                                            }.scrollContentBackground(.hidden).listRowBackground(Color("Background"))
                                        }.scrollContentBackground(.hidden).listRowBackground(Color("Background"))
                                    }
                                    else if searchResults.isEmpty && searchText.isEmpty {
                                        List{
                                            Section{
                                                Text("Whats for lunch?").frame(maxWidth: .infinity, maxHeight: .infinity)
                                            }.scrollContentBackground(.hidden).listRowBackground(Color("Background"))
                                        }.scrollContentBackground(.hidden).listRowBackground(Color("Background"))
                                    }
                                    Spacer()
                                    
                                    Spacer()
                                    
                                }.background(Color("Background"))  .ignoresSafeArea(.keyboard, edges: .bottom)
                                
                                
                            }.edgesIgnoringSafeArea(.vertical)  .frame(maxWidth: .infinity)  .ignoresSafeArea(.keyboard, edges: .bottom)
                            
                            
                        }.onChange(of: isFocused){ newvalue in
                            if isFocused{
                                cardPosition = .top
                            }
                            
                        }  .ignoresSafeArea(.keyboard, edges: .bottom)
                        
                            .onAppear {
                                startScanningIfNeeded()
                            }
                            .onChange(of: barcode) { newValue in
                                if let barcode = newValue {
                                    print("Barcode scanned: \(barcode)")
                                    isLoading = true
                                    addFoodSheetOpen = true
                                    dataFetcher.fetchFoodData(forBarcode: barcode, context: context, day: fetchTodayDay(context: context)) { fetchedFood, error in
                                        DispatchQueue.main.async {
                                            isLoading = false
                                            if let fetchedFood = fetchedFood {
                                                food = fetchedFood
                                                
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
                            }.onChange(of: searchText){
                                print("Loading")
                            }
                            .onChange(of: cardPosition){
                                if cardPosition == .bottom{
                                    isFocused = false
                                }
                                else if isFocused{
                                    cardPosition = .top
                                }
                            }
                            .sheet(isPresented: $addFoodSheetOpen) {
                                if isLoading {
                                    ZStack {
                                        
                                        VStack(spacing: 10) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(1.5)
                                            Text(loadingPrompts.randomElement() ?? "")
                                                .foregroundColor(.white)
                                                .font(.headline)
                                        }
                                        .padding()
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)).opacity(0.8))
                                    }
                                }
                                if let food = food {
                                    AddFoodSheet(food: food, selectedTab: $selectedTab).onAppear(){
                                        isSearchExpanded = false
                                    }
                                    .onDisappear {
                                        isScanning = true
                                        
                                        barcode = nil
                                        dismiss()
                                        cardPosition = .bottom
                                    }.interactiveDismissDisabled()
                                }
                            }  .ignoresSafeArea(.keyboard, edges: .bottom)
                        
                        
                    }  .ignoresSafeArea(.keyboard, edges: .bottom)
                    
                    // Computed Property for Today's Date
                    
                    
                }  .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }.scrollDisabled(true).scrollDismissesKeyboard(.interactively)
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
