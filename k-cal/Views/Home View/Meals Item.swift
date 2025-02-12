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
                Text("\(food.calories)k-cal").foregroundStyle(Color("k-cal"))
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
   @State var l: Food = Food(name: "TEst", calories: 100, day: Day(date: Date.now), meal: .breakfast)
    Meals_Item(food: l)
}
