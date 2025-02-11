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
       
        var body: some View
        {
                @State var today: Day = fetchTodayDay(context: context, calories: $todays_calories)
                
                NavigationStack
                {
                    
                    
                   
                    // text header todo: add rotating prompts
                    Form
                    {
                        Text("Today's Progress")
                            .frame(maxWidth: .infinity, alignment: .center)
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
                            print("Protein: \(protein), Carbs: \(carbs), Fat: \(fat)")
                        }
                        Button("Add Snack")
                        {
                            add_food(food: Food(name: "Snack", calories: 150, timeEaten: Date(), day: today, protein: 20, carbohydrates: 50, fat: 5), context: context)
                            fetchTodayDay(context: context, calories: $todays_calories)
                        }
                    }
                    
                    
                    
                }
        
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
        return output
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
