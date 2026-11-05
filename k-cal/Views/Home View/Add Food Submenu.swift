//
//  Add Food Submenu.swift
//  k-cal
//
//  Created by Michael Rizig on 2/12/25.
//

import SwiftUI

/// A full-screen flow for adding food, presented by the scan tab.
enum AddFoodRoute: Identifiable {
    case snapMeal
    case myFoods
    /// A barcode no source knows, for the user to fill in.
    case newCustomFood(barcode: String)

    var id: String {
        switch self {
        case .snapMeal: "snapMeal"
        case .myFoods: "myFoods"
        case let .newCustomFood(barcode): "newCustomFood-\(barcode)"
        }
    }
}

struct Add_Food_Submenu: View {
    @Binding var selectedTab: Int // Bind to ContentView's tab selection
    @State var meal: Meal?
    @State var isSearching = false
    @Binding var isSearchExpanded: Bool
    @Binding var addFoodRoute: AddFoodRoute?
    var body: some View {
        ZStack{
            Button(action: {
                selectedTab = 1
                
            }) {
                HStack {
                    Text("Scan")
                    Image(systemName: "barcode.viewfinder")
                }
            }
            
            Button(action: {
                selectedTab = 1
                addFoodRoute = .snapMeal
            }) {
                HStack {
                    Text("Snap Photo")
                    Image(systemName: "camera")
                }
            }

            Button(action: {
                selectedTab=1
                isSearchExpanded=true
            }) {
                HStack {
                    Text("Search")
                    Image(systemName: "magnifyingglass")
                }
            }
            Button(action: {
                selectedTab = 1
                addFoodRoute = .myFoods
            }) {
                Text("Custom")
                Image(systemName: "keyboard")
            }
        }
    }

    init(meal: Meal? = nil, selectedTab: Binding<Int>, isSearchExpanded: Binding<Bool>, addFoodRoute: Binding<AddFoodRoute?>) {
        self.meal = meal
        _selectedTab = selectedTab
        self._isSearchExpanded = isSearchExpanded
        self._addFoodRoute = addFoodRoute
    }
}

#Preview {
    @State var tab = 0
    @State var s  = false
    Add_Food_Submenu(selectedTab: $tab, isSearchExpanded: $s, addFoodRoute: .constant(nil))
}
