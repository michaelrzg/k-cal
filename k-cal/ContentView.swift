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

#Preview {
    ContentView()
}

