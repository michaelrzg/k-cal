//
//  UpdateFoodSheet 2.swift
//  k-cal
//
//  Created by Michael Rizig on 2/13/25.
//


import SwiftUI

struct AddFoodSheet: View {
    @Bindable var food: Food
    @State var servings: Int = 1
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @State var calorie_string: String = ""
    @State var calorie_per_serving_string: String
    
    let mealOptions = ["Breakfast", "Lunch", "Dinner", "Snack"]
    
    init(food: Food) {
        self.food = food
        _calorie_per_serving_string = State(initialValue: "\(food.calories_per_serving)") // Initialize with food.calories_per_serving
    }

    var body: some View {
        NavigationStack {
            Form {
                if let day = food.day {
                    DatePicker("Date", selection: Binding(
                        get: { day.date },
                        set: { food.day?.date = $0 }
                    ))
                } 
                
                HStack {
                    Text("Name:").frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    TextField("Name:", text: $food.name).multilineTextAlignment(.trailing)
                }
                Picker("Meal:", selection: $food.meal) {
                                    ForEach(mealOptions, id: \.self) { meal in
                                        Text(meal).tag(meal)
                                    }
                                }
                                .pickerStyle(.menu) 
                
                Picker("Servings:", selection: $food.servings) {
                    ForEach(1...100, id: \.self) { number in
                        Text("\(number)")
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: food.servings) { newValue in
                    food.calories = (Int(calorie_per_serving_string) ?? 0) * newValue
                }

                HStack {
                    Text("Calories / Serving:")
                    Spacer()
                    TextField("k-cal", text: $calorie_per_serving_string)
                        .keyboardType(.numberPad)
                        .onChange(of: calorie_per_serving_string) { newValue in
                            if let newCalories = Int(newValue) {
                                food.calories_per_serving = newCalories
                                food.calories = newCalories * food.servings
                            }
                        }
                        .multilineTextAlignment(.trailing)
                }


                HStack {
                    Spacer()
                    VStack {
                        Text("Protein").foregroundStyle(Color("Protein"))
                        TextField("g", value: $food.protein, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 50)
                    }
                    Spacer()
                    VStack {
                        Text("Carbs").foregroundStyle(Color("Carbohydrate"))
                        TextField("g", value: $food.carbohydrates, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 50)
                    }
                    Spacer()
                    VStack {
                        Text("Fat").foregroundStyle(Color("Fat"))
                        TextField("g", value: $food.fat, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 50)
                    }
                    Spacer()
                }

                // Macronutrient Circle Chart
                VStack {
                    MacronutrientRingView(fat: food.fat, protein: food.protein, carbs: food.carbohydrates, calories: food.calories)
                        .frame(width: 150, height: 150)
                        .padding(.top, 20)
                        .padding(.bottom,20)
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)


            }
            .navigationTitle("\(food.name)")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") {
                        print("Saving...")
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Cancel") {
                        print("Cancel...")
                        context.delete(food)
                        dismiss()
                    }
                }
            }
        }
    }
}
