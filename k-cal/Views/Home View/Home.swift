//
//  Home.swift
//  k-cal
//
//  Created by Michael Rizig on 2/11/25.
//
//
import Foundation
import SwiftData
import SwiftUI

struct Home: View {
    @Environment(\.modelContext) private var context

    @Query private var users: [User]
    @Query private var food_items: [Food]
    @Binding var selectedTab: Int // Bind to ContentView's tab selection
    @Binding var isSearchExpanded: Bool
    @State var user: User = .init(name: "Test", calorie_goal: 2500, protein_goal: 120, carb_goal: 250, fat_goal: 50)
    @State var calorie_goal: Int = 0
    @State var todays_calories: Int = 0
    @State var todays_progress: Float = 0.0
    @State var protein: Int = 0
    @State var carbs: Int = 0
    @State var fat: Int = 0
    @State var protein_progress: Float = 0.0
    @State var carbs_progress: Float = 0.0
    @State var fat_progress: Float = 0.0
    @State var excersise_calories: Int = 100 // TODO: Get health data from fitness app
    @State private var showing_edit_sheet = false
    @State private var food_being_edited: Food?

    var calorie_formula_font_size: CGFloat = 17

    var body: some View {
        @State var today: Day = fetchTodayDay(context: context, calories: $todays_calories)

        ZStack {
            Color("Background").zIndex(0).opacity(1)

            Form {
                // header containing date and time
                // Remaining calories section
                Section(header: Text(Date().formatted(date: .complete, time: .omitted)).position(x: 67, y: 80)) { ZStack {
                    Text("  Remaining Calories").position(x: 69, y: 12).padding(1).font(Font.system(size: 20)).bold()
                    HStack {
                        VStack {
                            Text("\(calorie_goal)").font(Font.system(size: calorie_formula_font_size)).bold()
                            Text("goal").font(Font.system(size: 14))
                        }

                        Spacer()

                        VStack {
                            Text("-").font(Font.system(size: calorie_formula_font_size))
                        }

                        Spacer()

                        VStack {
                            Text("\(todays_calories)").font(Font.system(size: calorie_formula_font_size))
                            Text("food").font(Font.system(size: 14))
                        }

                        Spacer()

                        VStack {
                            Text("+").font(Font.system(size: calorie_formula_font_size))
                        }

                        Spacer()
                        VStack {
                            Text("\(excersise_calories)").font(Font.system(size: calorie_formula_font_size))
                            Text("exercise").font(Font.system(size: 14))
                        }

                        Spacer()

                        VStack {
                            Text("=").font(Font.system(size: calorie_formula_font_size))
                        }

                        Spacer()

                        VStack {
                            Text("\(calorie_goal - todays_calories + excersise_calories)").font(Font.system(size: calorie_formula_font_size)).foregroundStyle(calorie_goal - todays_calories + excersise_calories < 0 ? .red : Color("k-cal")).bold()
                            Text("remaining").font(Font.system(size: 14))
                        }

                        Spacer()

                    }.position(x: 160, y: 56)
                }
                }.listRowInsets(EdgeInsets(top: 10, leading: 30, bottom: 55, trailing: 30))
                    .frame(height: 40).listRowBackground(Color("Foreground"))

                Section {
                    Text("Progress")
                        .listRowSeparator(.hidden)
                        .padding(1).font(Font.system(size: 20)).bold()
                    ZStack {
                        ProgressBar(progress: self.$todays_progress, calories: self.$todays_calories, protein_progress: self.$protein_progress, carb_progress: self.$carbs_progress, fat_progress: self.$fat_progress, total_fat: self.$fat, total_carbs: self.$carbs, total_protein: self.$protein)
                            .frame(width: 250.0, height: 150.0)
                            .padding(40.0)
                    }
                    .onAppear {
                        fetchTodayDay(context: context, calories: $todays_calories, protein: $protein, carbohydrates: $carbs, fats: $fat)
                        load_calorie_goal()
                    }
                    .onChange(of: todays_calories) { _ in
                        updateProgress()
                        fetchTodayDay(context: context, calories: $todays_calories)
                        print("Protein: \(protein), Carbs: \(carbs), Fat: \(fat)")
                    }
// test button
//                    Button("Add Snack") {
//                        add_food(food: Food(name: "Zaxby's", day: Day(date: Date()), protein: 10, carbohydrates: 10, fat: 10, meal: .lunch, servings: 1, calories_per_serving: 1500, sodium: 0, sugars: 0, fiber: 0, ingredients: "Ingredients", url:), context: context)
//                        fetchTodayDay(context: context, calories: $todays_calories)
//                    }

                }.listRowBackground(Color("Foreground"))
                Section {
                    Text("Meals")
                        .listRowSeparator(.hidden)
                        .padding(1).font(Font.system(size: 20)).bold()

                    Text("breakfast").listRowSeparator(.hidden).bold()
                    List {
                        ForEach(today.foods) { food in
                            if food.meal == "Breakfast" {
                                Meals_Item(food: food)
                                    .onTapGesture {
                                        food_being_edited = food
                                        print(food_items)
                                        showing_edit_sheet = true
                                    }
                            }

                        }.onDelete { indexes in
                            for index in indexes {
                                delete_food(food: today.foods[index])
                            }
                            fetchTodayDay(context: context, calories: $todays_calories)
                            updateProgress()
                        }
                        .onChange(of: food_being_edited) {
                            fetchTodayDay(context: context, calories: $todays_calories)
                            updateProgress()
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
                        ForEach(today.foods) { food in
                            if food.meal == "Lunch" {
                                Meals_Item(food: food)
                                    .onTapGesture {
                                        food_being_edited = food
                                        print(food.name)
                                        showing_edit_sheet = true
                                    }
                            }

                        }.onDelete { indexes in
                            for index in indexes {
                                delete_food(food: today.foods[index])
                            }
                            fetchTodayDay(context: context, calories: $todays_calories)
                            updateProgress()
                        }
                        Menu {
                            Add_Food_Submenu(meal: .breakfast, selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
                        } label: {
                            Text("add")
                        }
                    }

                    Text("dinner").listRowSeparator(.hidden).bold()
                    List {
                        ForEach(today.foods) { food in
                            if food.meal == "Dinner" {
                                Meals_Item(food: food)
                                    .onTapGesture {
                                        food_being_edited = food
                                        print(food.name)
                                        showing_edit_sheet = true
                                    }
                            }
                        }.onDelete { indexes in
                            for index in indexes {
                                delete_food(food: today.foods[index])
                            }
                            fetchTodayDay(context: context, calories: $todays_calories)
                            updateProgress()
                        }
                        Menu {
                            Add_Food_Submenu(meal: .breakfast, selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
                        } label: {
                            Text("add")
                        }
                    }

                    Text("snacks").listRowSeparator(.hidden).bold()
                    List {
                        ForEach(today.foods) { food in
                            if food.meal == "Snacks" {
                                Meals_Item(food: food)
                                    .onTapGesture {
                                        food_being_edited = food
                                        print(food.name)
                                        showing_edit_sheet = true
                                    }
                            }

                        }.onDelete { indexes in
                            for index in indexes {
                                delete_food(food: today.foods[index])
                            }
                            fetchTodayDay(context: context, calories: $todays_calories)
                            updateProgress()
                        }
                        Menu {
                            Add_Food_Submenu(meal: .breakfast, selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
                        } label: {
                            Text("add")
                        }
                    }
                }.listRowBackground(Color("Foreground"))
            }.listSectionSpacing(18)
                .sheet(item: $food_being_edited) { food in

                    UpdateFoodSheet(food: food).onDisappear {
                        food_being_edited = nil
                        showing_edit_sheet = false
                        fetchTodayDay(context: context, calories: $todays_calories, protein: $protein, carbohydrates: $carbs, fats: $fat)
                        updateProgress()
                    }.interactiveDismissDisabled()

                }.scrollContentBackground(.hidden)

        }.padding(.top, -60)
    }

    func updateProgress() {
        todays_progress = scale_progress(progress: min(Float(todays_calories) / Float(calorie_goal), 1.0))
        protein_progress = scale_progress(progress: Float(protein) / Float(user.protein_goal))
        carbs_progress = scale_progress(progress: Float(carbs) / Float(user.carb_goal))
        fat_progress = scale_progress(progress: Float(fat) / Float(user.fat_goal))
    }

    func load_calorie_goal() {
        calorie_goal = user.calorie_goal
    }

    func add_food(food: Food, context: ModelContext) {
        let today = fetchTodayDay(context: context)
        today.foods.append(food)
        protein = today.totalProtein
        carbs = today.totalCarbohydrates
        fat = today.totalFat
        try! context.save()
    }

    func delete_food(food: Food) {
        context.delete(food)
        try! context.save()
        fetchTodayDay(context: context, calories: $todays_calories, protein: $protein, carbohydrates: $carbs, fats: $fat)
        updateProgress()
        print(food_items.count)
    }

    init(selectedTab: Binding<Int>, isSearchExpanded: Binding<Bool>) {
        _selectedTab = selectedTab
        _isSearchExpanded = isSearchExpanded
        if !users.isEmpty {
            user = users[0]
        }
    }
}

func scale_progress(progress: Float) -> Float {
    var output = Float(progress) / 100
    output = Float(progress) * 0.6
    output += 0.3
    return min(output, 0.9)
}

func fetchTodayDay(context: ModelContext, calories: Binding<Int>? = nil, protein: Binding<Int>? = nil, carbohydrates: Binding<Int>? = nil, fats: Binding<Int>? = nil) -> Day {
    let todayStart = Calendar.current.startOfDay(for: Date())

    let fetchDescriptor = FetchDescriptor<Day>(
        predicate: #Predicate { $0.date == todayStart }
    )

    do {
        if let existingDay = try context.fetch(fetchDescriptor).first {
            // Update the state with the total calories, p, c, f
            calories?.wrappedValue = existingDay.foods.reduce(0) { $0 + $1.calories }
            protein?.wrappedValue = existingDay.totalProtein
            carbohydrates?.wrappedValue = existingDay.totalCarbohydrates
            fats?.wrappedValue = existingDay.totalFat
            carbohydrates?.wrappedValue = existingDay.foods.reduce(0) { $0 + $1.carbohydrates }
            fats?.wrappedValue = existingDay.foods.reduce(0) { $0 + $1.fat }
            try! context.save()
            return existingDay
        } else {
            let newDay = Day(date: todayStart)
            context.insert(newDay)
            try context.save()
            calories?.wrappedValue = 0 // Set to 0 for a new day
            return newDay
        }
    } catch {
        fatalError("Error fetching or creating today's Day: \(error)")
    }
}
