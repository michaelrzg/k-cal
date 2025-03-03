import AVFoundation
import SwiftData
import SwiftUI

struct FoodBarcodeScanner: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var days: [Day]
    @Query private var food_items: [Food]
    @Query(sort: [SortDescriptor(\Search.day, order: .reverse)]) var recentSearches: [Search]
    var uniqueRecentSearches: [Search] {
           var seen = Set<String>() // Create a Set to track seen items
           var uniqueItems = [Search]()

        for item in recentSearches {
            if !seen.contains(item.food.name) { // Check if the item has been seen
                   uniqueItems.append(item) // Add the item to the unique array
                seen.insert(item.food.name) // Add the item to the Set
               }
           }
           return uniqueItems // Return the array of unique items
       }
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
        "Summoning the food gods... 🍕",
        "Consulting the avocado oracle... 🥑",
        "Asking the cheeseburger council... 🍔",
        "Taco-vering all the details... 🌮",
        "Rolling the donut of destiny... 🍩",
        "Bribing the broccoli board... 🥦",
        "Slicing through the data... 🍉",
        "Fishing for facts... 🍣",
        "Calculating the cheese-to-crust ratio... 🍕",
        "Popping the data kernels... 🍿",
        "Marinating the results... 🍗",
        "Flipping through the pancake archives... 🥞"
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
                            BarcodeScannerView(barcode: $barcode, isScanning: $isScanning, dataFetcher: dataFetcher, context: context, day: fetchTodayDay(context: context))  .ignoresSafeArea(.keyboard, edges: .bottom).ignoresSafeArea().overlay(
                                ZStack {
                                    // Black overlay with 60% opacity
                                    Color.black.opacity(0.3)
                                        .edgesIgnoringSafeArea(.all)
                                        .overlay(
                                            // Clear rectangle in the center
                                            Rectangle()
                                                .frame(width: 200, height: 100)
                                                .blendMode(.destinationOut)
                                        )
                                        .overlay(
                                            // Clear rectangle in the center
                                            Rectangle()
                                                .stroke(Color.white,lineWidth: 2)
                                                .frame(width: 200, height: 100)
                                                
                                        )
                                }
                                    .compositingGroup().offset(y:-130) // Ensures blendMode works correctly
                            )
                                
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
                                    
                                    Handle()  .ignoresSafeArea(.keyboard, edges: .bottom)
                                    
                                    HStack {
                                        
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.blue)
                                            .padding(.leading, 8).scaledToFill()  .ignoresSafeArea(.keyboard, edges: .bottom)
                                        
                                        TextField("Search by name", text: $searchText)  .ignoresSafeArea(.keyboard, edges: .bottom).scrollDismissesKeyboard(.interactively)
                                        
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
                                                                
                                                                HStack{
                                                                    Text(item.brand)
                                                                        .font(.subheadline)
                                                                        .foregroundColor(.secondary)
                                                                    Spacer()
                                                                    Text("\(item.protein)")
                                                                    Text("p").foregroundStyle(Color("Protein"))
                                                                    Text("|")
                                                                    Text("\(item.carbohydrates)")
                                                                    Text("c").foregroundStyle(Color("Carbohydrate"))
                                                                    Text("|")
                                                                    Text("\(item.fat)")
                                                                    Text("f").foregroundStyle(Color("Fat"))
                                                                }
                                                            }
                                                            
                                                            Spacer()
                                                            
                                                            Button {
                                                                addFoodFromSearch(item: item)
                                                                searchText = ""
                                                            } label: {
                                                                Image(systemName: "plus.circle").scaleEffect(1.3)
                                                            }
                                                        }
                                                        .padding(.vertical, 6)
                                                        .listRowBackground(Color("Background"))
                                                    }
                                                }.listRowBackground(Color("Background"))
                                                Spacer()
                                            }.listRowBackground(Color("Foreground"))
                                                .scrollContentBackground(.hidden)
                                        }  .ignoresSafeArea(.keyboard, edges: .bottom)
                                    }
                                    else if searchText.isEmpty || !enterPressed{
                                        ZStack{
                                            Color("Background")
                                            List{
                                                Section(header: Text("History").font(.headline).foregroundColor(.primary)) {
                                                    ForEach(uniqueRecentSearches.prefix(5)) { item in
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
                                                                HStack{
                                                                    Text(item.food.brand ?? "")
                                                                        .font(.subheadline)
                                                                        .foregroundColor(.secondary)
                                                                    Spacer()
                                                                    Text("\(item.food.protein)")
                                                                    Text("p").foregroundStyle(Color("Protein"))
                                                                    Text("|")
                                                                    Text("\(item.food.carbohydrates)")
                                                                    Text("c").foregroundStyle(Color("Carbohydrate"))
                                                                    Text("|")
                                                                    Text("\(item.food.fat)")
                                                                    Text("f").foregroundStyle(Color("Fat"))
                                                                }
                                                            }
                                                            
                                                            Spacer()
                                                            
                                                            Button {
                                                                addFoodFromBarcode(item: item.food)
                                                            } label: {
                                                                Image(systemName: "plus.circle").scaleEffect(1.3)
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
                            
                        }.onChange(of: searchText) { newValue in
                            if newValue.isEmpty {
                                searchResults = [] // Clear search results
                                enterPressed = false // Reset enterPressed
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
                                if let food1 = food {
                                    AddFoodSheet(food: food1, selectedTab: $selectedTab).onAppear(){
                                        isSearchExpanded = false
                                    }
                                    .onDisappear {
                                        isScanning = true;
                                        food = nil;
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
    func addFoodFromBarcode(item: Food) {
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
