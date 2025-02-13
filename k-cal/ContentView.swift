//
//  ScanPage.swift
//  k-cal
//
//  Created by Michael Rizig on 2/10/25.
//
import Foundation
import SwiftUI
import SwiftData

struct ContentView: View {
    @State var meal: Meal?
    var body: some View {
        NavigationStack
        {
            
            
            // top bar with scan icon and  'kcal' title
            HStack
            {
                Image(systemName: "barcode.viewfinder").foregroundStyle(Color("k-cal"))
                Text("k-cal").font(.headline).foregroundStyle(Color("k-cal"))
                
            }
            
            // Bottom tabs
            TabView{
                Home()
                    .tabItem(){
                        Image(systemName: "house")
                        Text("Home")
                    }
                Scan()
                    .tabItem(){
                        Image(systemName: "barcode.viewfinder")
                        Text("Scan")
                    }
                Diary()
                    .tabItem(){
                        Image(systemName: "book")
                        Text("Log")
                    }
            }
        }
    }
    
}

#Preview {
    ContentView()
}

