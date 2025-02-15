//
//  k_calApp.swift
//  k-cal
//
//  Created by Michael Rizig on 2/10/25.
//

import SwiftData
import SwiftUI

@main
struct k_calApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [User.self, Day.self, Food.self])
    }
}
