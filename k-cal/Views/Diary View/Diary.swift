
import SwiftUI
import SwiftData

struct Diary: View {
    
    let BANNER_AD_ID = "ca-app-pub-3940256099942544/2435281174"
    
    @Binding var selectedTab: Int // Bind to ContentView's tab selection
    @Binding var isSearchExpanded: Bool
    @State private var selectedDate = Date()
    @Environment(\.modelContext) private var context
    @State private var foods: [Food] = []
    @State private var showing_edit_sheet = false
    @State private var food_being_edited: Food?
    var body: some View {
        ZStack{
            
            Color("Background").zIndex(0).opacity(1).ignoresSafeArea()
            Form {
                
                Section(header: Text(Date().formatted(date: .complete, time: .omitted))) {
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical).listRowBackground(Color("Foreground"))
                   
                }
              
                Section {
                    Text("\(selectedDate, style: .date)").listRowBackground(Color("Foreground"))
                    Text("Meals")
                        .listRowSeparator(.hidden)
                        .padding(1).font(Font.system(size: 20)).bold()
                    
                    Text("breakfast").listRowSeparator(.hidden).bold()
                    List {
                        ForEach(foods) { food in
                            if food.meal == "Breakfast" {
                                Meals_Item(food: food)
                                    .onTapGesture {
                                        food_being_edited = food
                                        showing_edit_sheet = true
                                    }
                            }

                        }.onDelete { indexes in
                            for index in indexes {
                                delete_food(food: foods[index])
                            }

                        }

                        Menu {
                            HStack {
                               Add_Food_Submenu(meal: .breakfast, selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
                            }

                        } label: {
                            Text("add")
                        }
                    }
                    
                    
                    
                    Text("lunch").listRowSeparator(.hidden).bold()
                    List {
                        ForEach(foods) { food in
                            if food.meal == "Lunch" {
                                Meals_Item(food: food)
                                    .onTapGesture {
                                        food_being_edited = food
                                        showing_edit_sheet = true
                                    }
                            }

                        }.onDelete { indexes in
                            for index in indexes {
                                delete_food(food: foods[index])
                            }

                        }

                        Menu {
                            HStack {
                                Add_Food_Submenu(meal: .lunch, selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
                            }

                        } label: {
                            Text("add")
                        }
                    }
                 
                    
                    Text("dinner").listRowSeparator(.hidden).bold()
                    List {
                        ForEach(foods) { food in
                            if food.meal == "Dinner" {
                                Meals_Item(food: food)
                                    .onTapGesture {
                                        food_being_edited = food
                                        showing_edit_sheet = true
                                    }
                            }

                        }.onDelete { indexes in
                            for index in indexes {
                                delete_food(food: foods[index])
                            }

                        }

                        Menu {
                            HStack {
                               Add_Food_Submenu(meal: .dinner, selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
                            }

                        } label: {
                            Text("add")
                        }
                    }
                
                    
                    Text("snacks").listRowSeparator(.hidden).bold()
                    List {
                        ForEach(foods) { food in
                            if food.meal == "Snacks" {
                                Meals_Item(food: food)
                                    .onTapGesture {
                                        food_being_edited = food
                                        showing_edit_sheet = true
                                    }
                            }

                        }.onDelete { indexes in
                            for index in indexes {
                                delete_food(food: foods[index])
                            }

                        }

                        Menu {
                            HStack {
                                Add_Food_Submenu(meal: .snack, selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
                            }

                        } label: {
                            Text("add")
                        }
                    }
                    
                }
                .listRowBackground(Color("Foreground"))
                AdBannerView(adUnitID: BANNER_AD_ID).frame(width: 320, height: 50).listRowBackground(Color("Foreground"))
            }.scrollContentBackground(.hidden)
                .sheet(item: $food_being_edited) { food in
                    
                    UpdateFoodSheet(food: food).onDisappear {
                        food_being_edited = nil
                        showing_edit_sheet = false
                        
                    }.interactiveDismissDisabled()
                }
            
        }.onAppear() {
            fetchFoodsForDate(date_selection: selectedDate);
        }
        .onChange(of: selectedDate){
            fetchFoodsForDate(date_selection: selectedDate)
        }
    }
    func fetchFoodsForDate(date_selection: Date) -> Day {
        print(foods)
        let startofday = Calendar.current.startOfDay(for: date_selection)
        let fetchDescriptor = FetchDescriptor<Day>(
            predicate: #Predicate { $0.date == startofday }
        )

        do {
            if let existingDay = try context.fetch(fetchDescriptor).first {
                // Update the state with the total calories, p, c, f
                foods = existingDay.foods
                return existingDay
            }
            else {
                print("newcreated")
                let newDay = Day(date: Date())

                foods = []
                return newDay
            }
        } catch {
            fatalError("Error fetching or creating today's Day: \(error)")
        }
        
    }
    func delete_food(food: Food) {
        var today = fetchFoodsForDate(date_selection: selectedDate)
        today.foods.removeAll (where:{ $0 == food } )
    }
    private var dateSelector: some View {
        HStack {
            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            }) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(selectedDate, style: .date)
            Spacer()
            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding()
    }
}
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Food.self, Day.self, configurations: config)
    return Diary(selectedTab: .constant(0), isSearchExpanded: .constant(false))
        .modelContainer(container)
}
