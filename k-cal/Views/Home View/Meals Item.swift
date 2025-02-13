//
//  Meals Item.swift
//  k-cal
//
//  Created by Michael Rizig on 2/12/25.
//

import SwiftUI

struct Meals_Item: View {
    @State var food: Food
    
    var body: some View {
        VStack {
            HStack{
                
                Text( "\(food.name)").frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Text("\(food.calories)/cal").foregroundStyle(Color("k-cal"))
            }
            HStack{
                Text("\(food.protein)🥩 ")
                Text("\(food.carbohydrates)🍚 ")
                Text("\(food.fat)🍩 ")
                Spacer()
            }
        }
        
    }
}

#Preview {
    @State var l: Food = Food(name: "Zaxby's", day: Day(date:Date()), protein: 10, carbohydrates: 10, fat: 10, meal: .lunch, servings: 1, calories_per_serving: 1500)
    Meals_Item(food: l)
}
