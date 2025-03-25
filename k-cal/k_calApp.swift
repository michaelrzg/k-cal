//
//  k_calApp.swift
//  k-cal
//
//  Created by Michael Rizig on 2/10/25.
//

import SwiftData
import SwiftUI
import GoogleMobileAds
class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(_ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    MobileAds.shared.start(completionHandler: nil)

    return true
  }
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("Ad received!")
        // ... your code ...
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("Ad failed to load: \(error.localizedDescription)")
        // ... your code ...
    }
}

@main
struct k_calApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [User.self, Day.self, Food.self, Search.self])
    }
}
