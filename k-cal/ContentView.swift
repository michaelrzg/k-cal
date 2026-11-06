import SwiftData
import SwiftUI

var HomeTopBannerId = "ca-app-pub-3940256099942544/2435281174"
var HomeBottomBannerId = "ca-app-pub-3940256099942544/2435281174"
var DiaryTopBannerId = "ca-app-pub-3940256099942544/2435281174"
var DiaryBottomBannerId = "ca-app-pub-3940256099942544/2435281174"
var AddFoodSheetTopBannerId = "ca-app-pub-3940256099942544/2435281174"
var AddFoodSheetBottomBannerId = "ca-app-pub-3940256099942544/2435281174"
var UpdateFoodSheetTopBannerId = "ca-app-pub-3940256099942544/2435281174"
var UpdateFoodSheetBottomBannerId = "ca-app-pub-3940256099942544/2435281174"

struct ContentView: View {
    private enum Tab: Hashable {
        case today
        case add
        case diary
    }

    @Environment(\.scenePhase) private var scenePhase
    @Query private var users: [User]
    @Query private var foods: [Food]
    @State private var flow = AddFoodFlow()
    @State private var tab = Tab.today
    @State private var showingProfile = false

    private var todaySnapshot: DailySnapshot {
        WidgetSync.snapshot(foods: foods, user: users.first, at: Date())
    }

    init() {
        let background = UIColor(named: "Background")
        // The window shows behind anything mid-animation, so it can't be left black.
        UIWindow.appearance().backgroundColor = background
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = background
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithTransparentBackground()
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        let scrolledBar = UINavigationBarAppearance()
        scrolledBar.configureWithDefaultBackground()
        scrolledBar.backgroundColor = background?.withAlphaComponent(0.8)
        UINavigationBar.appearance().standardAppearance = scrolledBar
    }

    var body: some View {
        TabView(selection: $tab) {
            TodayView(showingProfile: $showingProfile)
                .tabItem { Label("Today", systemImage: "house.fill") }
                .tag(Tab.today)
            AddFoodView()
                .tabItem { Label("Add Food", systemImage: "plus.circle.fill") }
                .tag(Tab.add)
            DiaryView(showingProfile: $showingProfile)
                .tabItem { Label("Diary", systemImage: "book.fill") }
                .tag(Tab.diary)
        }
        .tint(Theme.brand)
        .environment(flow)
        .modifier(AddFoodPresenter(flow: flow))
        .sheet(isPresented: $showingProfile) { ProfileView() }
        .fullScreenCover(isPresented: .constant(users.isEmpty)) { OnboardingView() }
        .sensoryFeedback(.success, trigger: flow.savedCount)
        .onChange(of: flow.savedCount) {
            if tab == .add { tab = .today }
        }
        .onChange(of: flow.searchRequests) { tab = .add }
        .onChange(of: todaySnapshot, initial: true) { _, snapshot in
            WidgetSync.publish(snapshot)
        }
        .onChange(of: scenePhase) {
            WidgetSync.publish(todaySnapshot)
        }
        .onOpenURL { url in
            open(AppLink(url: url))
        }
        .task {
            await FoodUpdater.shared.updateIfDue()
        }
    }

    private func open(_ link: AppLink?) {
        switch link {
        case .scan: flow.start(.scan)
        case .snap: flow.start(.snapMeal)
        case .search: flow.startSearch()
        case .custom: flow.start(.myFoods)
        case nil: break
        }
    }
}

#Preview {
    ContentView()
}
