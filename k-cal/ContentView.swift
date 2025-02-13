import Foundation
import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @State var meal: Meal?
    var body: some View {
        NavigationStack {
            HStack {
                Image(systemName: "barcode.viewfinder").foregroundStyle(Color("k-cal"))
                Text("k-cal").font(.headline).foregroundStyle(Color("k-cal"))
            }

            TabView {
                Home()
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }

                FoodBarcodeScanner()
                    .tabItem {
                        Image(systemName: "barcode.viewfinder")
                        Text("Scan")
                    }

                Diary()
                    .tabItem {
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
