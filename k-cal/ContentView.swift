import AVFoundation
import Foundation
import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State var meal: Meal?
    @State private var showUserView = false
    @State var isSearchExpanded: Bool = false
    @Query private var users: [User]
    var body: some View {
        NavigationStack {
            HStack {
                ZStack {
                    Color("Background").ignoresSafeArea()
                    HStack {
                        HStack {
                            HStack {
                                Image(systemName: "barcode.viewfinder").foregroundStyle(Color("k-cal")).padding(.top, 10)
                                Text("k-cal").font(.headline).foregroundStyle(Color("k-cal")).padding(.top, 10)
                            }
                        }.frame(maxWidth: .infinity, alignment: .center)

                    }.padding(.bottom, 10)
                    HStack {
                        Button(action: { // Wrap the Image in a Button
                            showUserView = true // Toggle the UserView
                        }) {
                            Image(systemName: "person.crop.circle")
                                .resizable()
                                .frame(width: 35, height: 35)
                                .foregroundStyle(Color("k-cal"))
                        }
                    }.frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 15)
                }.frame(maxHeight: 20)
            }
            ZStack {
                TabView(selection: $selectedTab) {
                    Home(selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
                        .tabItem {
                            Image(systemName: "house")
                            Text("Home")
                        }
                        .tag(0)

                    FoodBarcodeScanner(selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
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
            }.sheet(isPresented: $showUserView) { // Present UserView as a sheet
                UserPageView()
            }
        }
    }

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
