//
//  ScanPage.swift
//  k-cal
//
//  Created by Michael Rizig on 2/10/25.
//
import Foundation
import SwiftUI
import SwiftData

struct ContentView: View {
    
    @Environment(\.modelContext) private var context
    
    @Query private var users: [User]
    @Query private var food_items: [Food]
    
    
    @State var calorie_goal: Int = 0
    @State var todays_calories: Int = 0
    @State var todays_progress: Float = 0.0
    
   
    var body: some View {
        @State var today: Day = fetchTodayDay(context: context, calories: $todays_calories)
        NavigationStack{
            // top bar with scan icon and  'kcal' title
            HStack{
            Image(systemName: "barcode.viewfinder").foregroundStyle(Color("PrimaryColor"))
                Text("k-cal").font(.headline).foregroundStyle(Color("PrimaryColor"))
            }
            
            // text header todo: add rotating prompts
            Form{
                ZStack{
                    ProgressBar(progress: self.$todays_progress, calories: self.$todays_calories)
                        .frame(width: 250.0, height: 220.0)
                        .padding(40.0)
                }
                .onAppear {
                    fetchTodayDay(context: context, calories: $todays_calories)
                    load_calorie_goal()
                }
                .onChange(of: todays_calories) { newValue in
                    updateProgress()
                }
                Button("Add Snack") {
                                add_food(food: Food(name: "Snack", calories: 100, day: today), context: context)
                                fetchTodayDay(context: context, calories: $todays_calories) // Refresh today's data
                            }
            }
            
        }
        
        
        
    }
    func updateProgress() {
        todays_progress = scale_progress(progress: min(Float(todays_calories) / Float(calorie_goal), 1.0))
        print(calorie_goal)
    }
    
    func load_calorie_goal() {
        if let user = users.first {
            calorie_goal = user.calorie_goal
        }
    }
    
}
func scale_progress(progress:Float)-> Float {
    var output: Float = Float(progress)/100
    output = Float(progress) * 0.6
    output+=0.3
    return output
}
func fetchTodayDay(context: ModelContext, calories: Binding<Int>? = nil) -> Day {
    let todayStart = Calendar.current.startOfDay(for: Date())
    
    let fetchDescriptor = FetchDescriptor<Day>(
        predicate: #Predicate { $0.date == todayStart }
    )

    do {
        if let existingDay = try context.fetch(fetchDescriptor).first {
            // Update the state with the total calories
            calories?.wrappedValue = existingDay.foods.reduce(0) { $0 + $1.calories }
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

func add_food(food: Food, context: ModelContext){
    let today = fetchTodayDay(context: context)
    today.foods.append(food)
    
}

#Preview {
    ContentView()
}

