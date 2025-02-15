//
//  Add Food Submenu.swift
//  k-cal
//
//  Created by Michael Rizig on 2/12/25.
//

import SwiftUI

struct Add_Food_Submenu: View {
    @Binding var selectedTab: Int // Bind to ContentView's tab selection
    @State var meal: Meal?
    @State var isSearching = false
    @Binding var isSearchExpanded: Bool
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
                selectedTab=1
                isSearchExpanded=true
            }) {
                HStack {
                    Text("Search")
                    Image(systemName: "magnifyingglass")
                }
            }
            Button(action: {}) {
                Text("Custom")
                Image(systemName: "keyboard")
            }
        }
    }

    init(meal: Meal? = nil, selectedTab: Binding<Int>, isSearchExpanded: Binding<Bool>) {
        self.meal = meal
        _selectedTab = selectedTab
        self._isSearchExpanded = isSearchExpanded
    }
}

#Preview {
    @State var tab = 0
    @State var s  = false
    Add_Food_Submenu(selectedTab: $tab, isSearchExpanded: $s)
}
