//
//  UpdateFoodSheet.swift
//  k-cal
//
//  Created by Michael Rizig on 2/11/25.
//

import SwiftUI

struct UpdateFoodSheet: View {
    @Bindable var food: Food
    @State var servings: Int = 1
    @Environment(\.dismiss) var dismiss
    
    @State var calorie_string: String = ""
    var body: some View {
        NavigationStack{
            Form{
                DatePicker("Date", selection: $food.day.date)
                TextField("Name", text: $food.name)
                Picker("Servings", selection: $servings){
                    ForEach(1...100, id: \.self) { number in
                                    Text("\(number)")
                                }
                }.pickerStyle(.menu)
                // TODO:
                TextField("Calories Per Serving", text:  $calorie_string).keyboardType(.numberPad).onChange(of: calorie_string) { newValue in
                    food.calories = Int(newValue) ?? 0
                    print(food.calories)
                }
                
            }.navigationTitle("Update \(food.name)")
        }
    }
}

#Preview {
    UpdateFoodSheet(food: Food(name: "foo", calories: 3, day: Day(date: Date()), meal: .breakfast))
}
