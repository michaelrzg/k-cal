import Foundation
import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @State private var selectedTab = 0
    @State var meal: Meal?
    var body: some View {
        NavigationStack {
                    ZStack {
                        Color("Background").ignoresSafeArea()
                        HStack {
                            Image(systemName: "barcode.viewfinder").foregroundStyle(Color("k-cal")).padding(.top, 10)
                            Text("k-cal").font(.headline).foregroundStyle(Color("k-cal")).padding(.top, 10)
                        }.padding(.bottom, 10)
                    }.frame(maxHeight: 20)

                    ZStack {
                        TabView(selection: $selectedTab) {
                            Home()
                                .tabItem {
                                    Image(systemName: "house")
                                    Text("Home")
                                }
                                .tag(0)

                            FoodBarcodeScanner(selectedTab: $selectedTab)
                                .tabItem {
                                    Image(systemName: "barcode.viewfinder")
                                    Text("Scan")
                                }
                                .tag(1)

                            Diary()
                                .tabItem {
                                    Image(systemName: "book")
                                    Text("Log")
                                }
                                .tag(2)
                        }
                        .scrollIndicators(.hidden)
                    }
                }    }
    init() {
        let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color("Background"))
        UITabBar.appearance().standardAppearance = appearance
           if #available(iOS 15.0, *) {
               UITabBar.appearance().scrollEdgeAppearance = appearance
           }
    }
}
#Preview {
    ContentView()
}
