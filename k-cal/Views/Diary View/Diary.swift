
import SwiftUI
import SwiftData
import Foundation
var global_selected_date:Date = Calendar.current.startOfDay(for: Date());
struct Diary: View {
    
    
    @Binding var selectedTab: Int // Bind to ContentView's tab selection
    @Binding var isSearchExpanded: Bool
    @Binding var selectedDate:Date
    @Environment(\.modelContext) private var context
    @State private var foods: [Food] = []
    @State private var showing_edit_sheet = false
    @State private var food_being_edited: Food?
    
    @State var todays_calories: Int = 0
    @State var todays_progress: Float = 0.0
    @State var protein: Int = 0
    @State var carbs: Int = 0
    @State var fat: Int = 0
    @State var protein_progress: Float = 0.0
    @State var carbs_progress: Float = 0.0
    @State var fat_progress: Float = 0.0
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
                //MacronutrientRingView(fat: $fat.wrappedValue, protein: $protein.wrappedValue, carbs: $carbs.wrappedValue, calories: $todays_calories.wrappedValue).padding(10).listRowBackground(Color("Foreground"))
                Section{
                    AdBannerView(adUnitID: DiaryBottomBannerId).frame(width: 320, height: 50).listRowBackground(Color("Foreground"))
                }
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
            global_selected_date = Calendar.current.startOfDay(for: selectedDate);
            
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
                todays_calories = existingDay.foods.reduce(0) { $0 + $1.calories }
                protein = existingDay.totalProtein
                carbs = existingDay.totalCarbohydrates
                fat = existingDay.totalFat
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
        fetchFoodsForDate(date_selection: selectedDate);
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
    return Diary(selectedTab: .constant(0), isSearchExpanded: .constant(false), selectedDate: .constant(Date()))
        .modelContainer(container)
}
