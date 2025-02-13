//
//  Add Food Submenu.swift
//  k-cal
//
//  Created by Michael Rizig on 2/12/25.
//

import SwiftUI

struct Add_Food_Submenu: View {
    @State var meal: Meal?
    var body: some View {
        Button(action: {
            
        }){
            HStack{
                Text("Scan")
                Image(systemName: "barcode.viewfinder")
            }
        }
        
    
        Button(action: {}){
        HStack{
            Text("Search")
            Image(systemName: "magnifyingglass")
        }
    }
        Button(action: {}){
            Text("Custom")
            Image(systemName: "keyboard")
        }
    }
    init(meal: Meal? = nil) {
        self.meal = meal
        
    }
    
}

#Preview {
    Add_Food_Submenu()
}
