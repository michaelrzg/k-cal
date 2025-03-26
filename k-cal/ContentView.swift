import AVFoundation
import Foundation
import SwiftData
import SwiftUI
import GoogleMobileAds

struct ContentView: View {
    @AppStorage("hasLaunchedBefore") var hasLaunchedBefore = false
    @State private var selectedTab = 0
    @State var meal: Meal?
    @State private var showUserView = false
    @State var isSearchExpanded: Bool = false
    @State var welcome_complete: Bool = false
    @State var header_text: String = "k-cal"
    var bannerView: BannerView!
    @Query private var users: [User]
    var body: some View {
        ZStack{}.onAppear(){
            if users.isEmpty == true{
                hasLaunchedBefore = false
            }
        }.fullScreenCover(isPresented: .constant(!hasLaunchedBefore && !welcome_complete)) {
            WelcomeView(welcome_complete: $welcome_complete)
                .onDisappear {
                    if !hasLaunchedBefore, !users.isEmpty {
                        hasLaunchedBefore = true
                        print("First launch complete")
                    }
                }.ignoresSafeArea(.keyboard, edges: .bottom)
            
        }
        Group{
            
                
                NavigationStack {
                    HStack {
                        ZStack {
                            Color("Background").ignoresSafeArea()
                            HStack {
                                HStack {
                                    HStack {
                                        Image(systemName: "barcode.viewfinder").foregroundStyle(Color("k-cal")).padding(.top, 10)
                                        Text(header_text).font(.headline).foregroundStyle(Color("k-cal")).padding(.top, 10)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .center)
                                
                            }.padding(.bottom, 10)
                            HStack {
                                Button(action: { // Wrap the Image in a Button
                                    showUserView = true // Toggle the UserView
                                }) {
                                    Image(systemName: "person.crop.circle")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .foregroundStyle(Color("k-cal"))
                                }
                            }.frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 15)
                        }.frame(maxHeight: 25)
                    }
                    ZStack {
                        TabView(selection: $selectedTab) {
                            Home(selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded, welcome_complete: $welcome_complete).onAppear() {
                               
                            }
                                .tabItem {
                                    Image(systemName: "house")
                                    Text("home")
                                    
                                }
                                .tag(0)
                            
                            FoodBarcodeScanner(selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
                                .tabItem {
                                    Image(systemName: "barcode.viewfinder")
                                    Text("scan/search")
                                }
                                .tag(1)
                            
                            Diary(selectedTab: $selectedTab, isSearchExpanded: $isSearchExpanded)
                                .tabItem {
                                    Image(systemName: "book")
                                    Text("diary")
                                }
                                .tag(2)
                        }
                        .scrollIndicators(.hidden)
                        
                    }.sheet(isPresented: $showUserView) { // Present UserView as a sheet
                        UserPageView()
                    }.onChange(of: selectedTab){
                         if selectedTab == 0{
                             withAnimation(.easeInOut(duration: 0.5)){
                                header_text = "k-cal"
                            }
                            
                        }
                        else if selectedTab == 1{
                            withAnimation(.easeInOut(duration: 0.5)){
                                header_text = "scan barcode"
                            }
                            
                        }
                        else if selectedTab == 2{
                            withAnimation(.easeInOut(duration: 0.5)){
                                header_text = "diary"
                            }
                        }
                    }
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
struct MyLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon
                .imageScale(.large) // Adjust image size
                .padding(.top, 5) // Adjust this value
            configuration.title
        }
    }
}
#Preview {
    ContentView()
}
