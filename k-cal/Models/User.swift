//
//  User.swift
//  k-cal
//
//  Created by Michael Rizig on 2/10/25.
//
import SwiftData
import SwiftUI

@Model
class User: Identifiable {
    var id: String
    var name: String
    var calorie_goal: Int
    var protein_goal: Int
    var carb_goal: Int
    var fat_goal: Int

    init(name: String, calorie_goal: Int, protein_goal: Int, carb_goal: Int, fat_goal: Int) {
        self.name = name
        self.calorie_goal = calorie_goal
        self.protein_goal = protein_goal
        self.carb_goal = carb_goal
        self.fat_goal = fat_goal
        id = UUID().uuidString
    }
}
