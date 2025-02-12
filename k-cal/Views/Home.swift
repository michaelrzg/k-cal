//
//  Home.swift
//  k-cal
//
//  Created by Michael Rizig on 2/11/25.
//
//
import Foundation
import SwiftUI
import SwiftData

struct Home: View {
        
        @Environment(\.modelContext) private var context
        
        @Query private var users: [User]
        @Query private var food_items: [Food]
        
        @State var user: User = User(name: "Test", calorie_goal: 2500, protein_goal: 120, carb_goal: 250, fat_goal: 50)
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
    
        var calorie_formula_font_size: CGFloat = 15
    
    
        var body: some View
        {
                @State var today: Day = fetchTodayDay(context: context, calories: $todays_calories)
                
            ZStack
            {
                
                       
                Form
                {    // header containing date and time
                    // Remaining calories section
                    Section(header: Text(Date().formatted(date: .complete, time: .omitted)).position(x:67,y:80))
                    {   ZStack{
                        Text("Remaining Calories").position(x:69,y:12).padding(1).font(Font.system(size: 20)).bold()
                        HStack{
                            
                            VStack{
                                Text("\(calorie_goal)").font(Font.system(size: calorie_formula_font_size)).bold()
                                Text("goal").font(Font.system(size: 12))
                            }
                            
                            Spacer()

                            VStack{
                                Text("-").font(Font.system(size: calorie_formula_font_size))
                            }
                            
                            Spacer()
                            
                            VStack{
                                Text("\(todays_calories)").font(Font.system(size: calorie_formula_font_size))
                                Text("food").font(Font.system(size: 12))
                            }
                            
                            Spacer()
                            
                            VStack{
                                Text("+").font(Font.system(size: calorie_formula_font_size))
                            }
                            
                            Spacer()
                            VStack{
                                Text("\(excersise_calories)").font(Font.system(size: calorie_formula_font_size))
                                Text("exercise").font(Font.system(size: 12))
                            }
                            
                            Spacer()
                            
                            VStack{
                                Text("=").font(Font.system(size: calorie_formula_font_size))
                            }
                            
                            Spacer()
                            
                            VStack{
                                Text("\(calorie_goal - todays_calories + excersise_calories)").font(Font.system(size: calorie_formula_font_size)).foregroundStyle(calorie_goal - todays_calories + excersise_calories < 0 ? .red : Color("k-cal")).bold()
                                Text("remaining").font(Font.system(size: 12))
                            }
                            
                            Spacer()
                            
                        }.position(x:160,y:56)
                        }
                    }    .listRowInsets(EdgeInsets(top: 10, leading: 30, bottom: 55, trailing: 30))
                        .frame(height: 40)
                    
                    
                    Section{
                        
                        Text("Calorie Breakdown")
                            .listRowSeparator(.hidden)
                            .padding(1).font(Font.system(size: 20)).bold()
                        ZStack
                        {
                            ProgressBar(progress: self.$todays_progress, calories: self.$todays_calories, protein_progress: self.$protein_progress, carb_progress: self.$carbs_progress, fat_progress: self.$fat_progress, total_fat: self.$fat, total_carbs: self.$carbs, total_protein: self.$protein)
                                .frame(width: 250.0, height: 150.0)
                                .padding(40.0)
                        }
                        .onAppear
                        {
                            fetchTodayDay(context: context, calories: $todays_calories, protein: $protein, carbohydrates: $carbs, fats: $fat )
                            load_calorie_goal()
                        }
                        .onChange(of: todays_calories)
                        { newValue in
                            updateProgress()
                            fetchTodayDay(context: context, calories: $todays_calories)
                            print("Protein: \(protein), Carbs: \(carbs), Fat: \(fat)")
                        }
                        Button("Add Snack")
                        {
                            add_food(food: Food(name: "Snack", calories: 150, timeEaten: Date(), day: today, protein: 20, carbohydrates: 50, fat: 5, meal: .breakfast), context: context)
                            fetchTodayDay(context: context, calories: $todays_calories)
                        }
                        
                    }
                    Section{
                        Text("Meals")
                            .listRowSeparator(.hidden)
                            .padding(1).font(Font.system(size: 20)).bold()
                    
                        Text("Breakfast").listRowSeparator(.hidden).bold()
                        List{
                            ForEach(food_items){ food in
                                if food.meal == "Breakfast" {
                                    Text(" \(food.name)").listRowSeparator(.hidden).onTapGesture(perform: {
                                        food_being_edited = food
                                    })
                                }
                                
                            }.onDelete{ indexes in
                                for index in indexes {
                                    delete_food(food: food_items[index])
                                }
                                
                            }
                            
                            Menu{
                                Button("Scan"){}
                                Button("Search"){}
                                Button("Add Manually"){}
                            } label: {
                                Text("Add")
                            }
                        }.sheet(item: $food_being_edited ){ food in
                            UpdateFoodSheet(food: food)
                        }
                        
                        Text("Lunch").listRowSeparator(.hidden).bold()
                        List{
                            ForEach(food_items){ food in
                                if food.meal == "Lunch"{
                                    Text(" \(food.name)").listRowSeparator(.hidden)
                                }
                                
                            }
                            Menu{
                                Button("Scan"){}
                                Button("Search"){}
                                Button("Add Manually"){}
                            } label: {
                                Text("Add")
                            }
                        }
                        
                        Text("Diner").listRowSeparator(.hidden).bold()
                        List{
                            ForEach(food_items){ food in
                                if food.meal == "Dinner"{
                                    Text(" \(food.name)").listRowSeparator(.hidden)
                                }
                                
                            }
                            Menu{
                                Button("Scan"){}
                                Button("Search"){}
                                Button("Add Manually"){}
                            } label: {
                                Text("Add")
                            }
                        }
                        
                        Text("Snacks").listRowSeparator(.hidden).bold()
                        List{
                            ForEach(food_items){ food in
                                if food.meal == "Snack"{
                                    Text(" \(food.name)").listRowSeparator(.hidden)
                                }
                                
                            }
                            Menu{
                                Button("Scan"){}
                                Button("Search"){}
                                Button("Add Manually"){}
                            } label: {
                                Text("Add")
                            }
                        }
                    }
                }.listSectionSpacing(18)
                
                
                
            }.padding(.top,-60)
            
                
            
            
                    
                    
                    
                
            
        
        }
        
    func updateProgress()
        {
            todays_progress = scale_progress(progress: min(Float(todays_calories) / Float(calorie_goal), 1.0))
            print(calorie_goal)
            protein_progress = scale_progress(progress: Float(protein)/Float(user.protein_goal))
            carbs_progress = scale_progress(progress: Float(carbs)/Float(user.carb_goal))
            fat_progress = scale_progress(progress: Float(fat)/Float(user.fat_goal))
        }
        
    func load_calorie_goal()
        {
                calorie_goal = user.calorie_goal
        }
    func add_food(food: Food, context: ModelContext)
        {
            let today = fetchTodayDay(context: context)
            today.foods.append(food)
            protein = today.totalProtein
            carbs = today.totalCarbohydrates
            fat = today.totalFat
            try! context.save()
            
        }
    func delete_food(food: Food){
        context.delete(food)
        try! context.save()
        print(food_items.count)
    }
    init(){
            
            if !users.isEmpty {
                user = users[0]
            }
        
    }
}

    func scale_progress(progress:Float)-> Float
    {
        var output: Float = Float(progress)/100
        output = Float(progress) * 0.6
        output+=0.3
        return min(output,0.9)
    }
    func fetchTodayDay(context: ModelContext, calories: Binding<Int>? = nil, protein: Binding<Int>? = nil, carbohydrates: Binding<Int>? = nil, fats: Binding<Int>? = nil) -> Day
    {
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




#Preview {
    Home()
}
