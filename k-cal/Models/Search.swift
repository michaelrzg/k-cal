//
//  SearchHistory.swift
//  k-cal
//
//  Created by Michael Rizig on 2/15/25.
//

import SwiftData
import Foundation
@Model
class Search: Identifiable{
    
     var food: Food
    var day: Date
    
    init(food: Food, day: Date){
        self.food = food
        self.day = day
    }
    
    
    
}
