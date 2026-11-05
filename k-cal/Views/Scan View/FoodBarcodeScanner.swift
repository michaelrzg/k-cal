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
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]
    private let repository = FoodRepository.shared
    @State private var isScanning = true
    @State private var barcode: String?
    @State private var food: Food?
    @State private var searchTask: Task<Void, Never>?
    @State private var lookupFailure: LookupFailure?
    @State private var addFoodSheetOpen: Bool = false
    @State private var isLoading: Bool = false
    @State private var searchText: String = ""
    @State private var searchResults: [FoodProduct] = []
    @State private var cardPosition: CardPosition = .bottom
    @State private var enterPressed: Bool = false
    @Binding private var isSearchExpanded: Bool
    @Binding private var addFoodRoute: AddFoodRoute?
    /// Builds the Food a finished add-food route chose, once its cover is gone.
    @State private var pendingFood: ((Day, Meal) -> Food)?
    @Binding var selectedTab: Int
    @Binding var selectedDate: Date
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

    init(selectedTab: Binding<Int>, isSearchExpanded: Binding<Bool>, addFoodRoute: Binding<AddFoodRoute?>, selectedDate: Binding<Date>) {
        _selectedTab = selectedTab
        _selectedDate = selectedDate
        self._isSearchExpanded = isSearchExpanded
        self._addFoodRoute = addFoodRoute
    }

    var body: some View {
        GeometryReader{ geo in
            ScrollView{
                ZStack {
                    ZStack {
                        if isScanning {
                            BarcodeScannerView(barcode: $barcode, isScanning: $isScanning)  .ignoresSafeArea(.keyboard, edges: .bottom).ignoresSafeArea().overlay(
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

                                        Button {
                                            addFoodRoute = .myFoods
                                        } label: {
                                            Image(systemName: "square.and.pencil")
                                                .foregroundColor(.blue)
                                        }
                                        .accessibilityLabel("My foods")

                                        Button {
                                            addFoodRoute = .snapMeal
                                        } label: {
                                            Image(systemName: "camera")
                                                .foregroundColor(.blue)
                                                .padding(.trailing, 12)
                                        }
                                        .accessibilityLabel("Snap a meal")
                                    }  .ignoresSafeArea(.keyboard, edges: .bottom)
                                        .frame(height: 50)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color("Foreground")))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                    
                                        .listRowBackground(Color("Background")).padding(.horizontal,10)
                                   
                                    if !searchResults.isEmpty || !matchingCustomFoods.isEmpty {
                                        ZStack{
                                            Color("Background")
                                            List{
                                                if !matchingCustomFoods.isEmpty {
                                                    Section(header: Text("My Foods").font(.headline).foregroundColor(.primary)) {
                                                        ForEach(matchingCustomFoods) { item in
                                                            FoodProductRow(product: item.product) {
                                                                review(item.product)
                                                                searchText = ""
                                                            }
                                                            .listRowBackground(Color("Background"))
                                                        }
                                                    }.listRowBackground(Color("Background"))
                                                }
                                                if !searchResults.isEmpty {
                                                    Section {
                                                        ForEach(searchResults) { item in
                                                            FoodProductRow(product: item) {
                                                                review(item)
                                                                searchText = ""
                                                            }
                                                            .listRowBackground(Color("Background"))
                                                        }
                                                    } header: {
                                                        Text("Search Results").font(.headline).foregroundColor(.primary)
                                                    } footer: {
                                                        Text("Data from USDA FoodData Central, Open Food Facts and Health Canada.")
                                                    }.listRowBackground(Color("Background"))
                                                }
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
                                                                logAgain(item.food)
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
                                selectedDate = global_selected_date;
                            }
                            .onChange(of: barcode) { newValue in
                                if let barcode = newValue {
                                    lookUp(barcode: barcode)
                                }
                            }
                            .onChange(of: cardPosition){
                                if cardPosition == .bottom{
                                    isFocused = false
                                }
                                else if isFocused{
                                    cardPosition = .top
                                }
                            }
                            .task(id: isSearchExpanded) {
                                // Runs on first appearance too, for a request made as the tab opens. Focus has to
                                // wait for the card, or it's dropped for a field that isn't on screen yet.
                                guard isSearchExpanded else { return }
                                cardPosition = .top
                                try? await Task.sleep(for: .milliseconds(400))
                                isFocused = true
                                isSearchExpanded = false
                            }
                            .onChange(of: addFoodRoute?.id) {
                                // The system camera can't start while the barcode scanner holds the capture session.
                                if addFoodRoute != nil {
                                    isScanning = false
                                }
                            }
                            .fullScreenCover(item: $addFoodRoute, onDismiss: finishAddFoodRoute) { route in
                                switch route {
                                case .snapMeal:
                                    SnapMealView { estimate, name in
                                        pendingFood = { day, meal in Food(estimate: estimate, name: name, day: day, meal: meal) }
                                    }
                                case .myFoods:
                                    MyFoodsView(onPick: reviewAfterRoute)
                                case let .newCustomFood(barcode):
                                    CustomFoodEditor(barcode: barcode) { reviewAfterRoute($0.product) }
                                }
                            }
                            .alert(item: $lookupFailure) { failure in
                                if let barcode = failure.unknownBarcode {
                                    Alert(
                                        title: Text("Product not found"),
                                        message: Text("Add it as a custom food and it will be found next time."),
                                        primaryButton: .default(Text("Add Food")) {
                                            addFoodRoute = .newCustomFood(barcode: barcode)
                                        },
                                        secondaryButton: .cancel(Text("Keep Scanning"), action: resumeScanning)
                                    )
                                } else {
                                    Alert(
                                        title: Text("Lookup failed"),
                                        message: Text(failure.message),
                                        dismissButton: .default(Text("OK"), action: resumeScanning)
                                    )
                                }
                            }
                            .sheet(isPresented: $addFoodSheetOpen) {
                                if let food1 = food {
                                    AddFoodSheet(food: food1, selectedTab: $selectedTab, selectedDate: $selectedDate).onAppear(){
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
    

    private struct LookupFailure: Identifiable {
        let id = UUID()
        let message: String
        var unknownBarcode: String?
    }

    private var matchingCustomFoods: [CustomFood] {
        searchText.isEmpty ? [] : customFoods.filter { $0.matches(searchText) }
    }

    func performSearch(searchTerm: String) {
        searchTask?.cancel()
        isLoading = true
        let repository = repository
        searchTask = Task {
            do {
                let results = try await repository.search(searchTerm)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
                // Custom foods are still on screen, so the search isn't a dead end.
                if matchingCustomFoods.isEmpty {
                    lookupFailure = LookupFailure(message: error.localizedDescription)
                }
            }
            isLoading = false
        }
    }

    /// Custom foods come first, so a product entered once is found offline and overrides the databases.
    private func lookUp(barcode: String) {
        isScanning = false
        if let custom = customFoods.first(where: { $0.hasBarcode(barcode) }) {
            review(custom.product)
            return
        }
        isLoading = true
        let repository = repository
        Task {
            do {
                if let product = try await repository.product(barcode: barcode) {
                    review(product)
                } else {
                    lookupFailure = LookupFailure(message: "", unknownBarcode: barcode)
                }
            } catch {
                lookupFailure = LookupFailure(message: error.localizedDescription)
            }
            isLoading = false
        }
    }

    private func review(_ product: FoodProduct) {
        open(Food(product: product, day: fetchTodayDay(context: context), meal: currentMeal))
    }

    private func logAgain(_ logged: Food) {
        open(Food(copying: logged, day: fetchTodayDay(context: context), meal: currentMeal))
    }

    private func open(_ newFood: Food) {
        food = newFood
        isScanning = false
        addFoodSheetOpen = true
    }

    private var currentMeal: Meal {
        Meal(hour: Calendar.current.component(.hour, from: Date()))
    }

    private func reviewAfterRoute(_ product: FoodProduct) {
        pendingFood = { day, meal in Food(product: product, day: day, meal: meal) }
    }

    private func finishAddFoodRoute() {
        guard let makeFood = pendingFood else {
            resumeScanning()
            return
        }
        pendingFood = nil
        open(makeFood(fetchTodayDay(context: context), currentMeal))
    }

    private func resumeScanning() {
        barcode = nil
        isScanning = true
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
