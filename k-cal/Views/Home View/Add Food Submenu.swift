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
    var body: some View {
        Button(action: {
            selectedTab = 1

        }) {
            HStack {
                Text("Scan")
                Image(systemName: "barcode.viewfinder")
            }
        }

        Button(action: {}) {
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

    init(meal: Meal? = nil, selectedTab: Binding<Int>) {
        self.meal = meal
        _selectedTab = selectedTab
    }
}

#Preview {
    @State var tab = 0
    Add_Food_Submenu(selectedTab: $tab)
}
