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
    var body: some View {
        NavigationStack
        {
            
            
            // top bar with scan icon and  'kcal' title
            HStack
            {
                Image(systemName: "barcode.viewfinder").foregroundStyle(Color("PrimaryColor"))
                Text("k-cal").font(.headline).foregroundStyle(Color("PrimaryColor"))
                
            }
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

