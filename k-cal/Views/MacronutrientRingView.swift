//
//  MacronutrientRingView.swift
//  k-cal
//
//  Created by Michael Rizig on 2/13/25.
//


import SwiftUI
// Macronutrient Circle Chart
struct MacronutrientRingView: View {
    var fat: Int
    var protein: Int
    var carbs: Int
    var calories: Int
    
    var total: CGFloat {
        CGFloat(fat + protein + carbs)
    }
    
    var fatRatio: CGFloat {
        total > 0 ? CGFloat(fat) / total : 0
    }
    
    var proteinRatio: CGFloat {
        total > 0 ? CGFloat(protein) / total : 0
    }
    
    var carbsRatio: CGFloat {
        total > 0 ? CGFloat(carbs) / total : 0
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.2), lineWidth: 15)
            
            Circle()
                .trim(from: 0, to: fatRatio)
                .stroke(Color("Fat"), lineWidth: 15)
                .rotationEffect(.degrees(-90))
            
            Circle()
                .trim(from: fatRatio, to: fatRatio + proteinRatio)
                .stroke(Color("Protein"), lineWidth: 15)
                .rotationEffect(.degrees(-90))
            
            Circle()
                .trim(from: fatRatio + proteinRatio, to: 1)
                .stroke(Color("Carbohydrate"), lineWidth: 15)
                .rotationEffect(.degrees(-90))
            
            VStack {
                Text("\(calories)")
                    .font(.system(size: 30, weight: .bold))
                Text("cal")
                    .font(.system(size: 14, weight: .regular))
            }
        }
    }
}
