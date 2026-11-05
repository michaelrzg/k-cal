//
//  WidgetTests.swift
//  k-calTests
//

import Foundation
import SwiftData
import Testing
@testable import k_cal

struct DailySnapshotTests {
    private let calendar = Calendar.current
    private let defaults = UserDefaults(suiteName: "k-cal-tests-\(UUID().uuidString)")!

    private var today: Date { calendar.startOfDay(for: Date()) }

    @Test func progressStaysBetweenZeroAndOne() {
        #expect(DailySnapshot.progress(50, of: 100) == 0.5)
        #expect(DailySnapshot.progress(300, of: 100) == 1)
        #expect(DailySnapshot.progress(-5, of: 100) == 0)
        #expect(DailySnapshot.progress(50, of: 0) == 0)
    }

    @Test func savedDayComesBack() {
        var snapshot = DailySnapshot(day: today)
        snapshot.calories = 1240
        snapshot.save(defaults: defaults)
        #expect(DailySnapshot.load(for: Date(), defaults: defaults) == snapshot)
    }

    @Test func yesterdaysTotalsDoNotCarryOverButGoalsDo() throws {
        var snapshot = DailySnapshot(day: today)
        snapshot.calories = 1240
        snapshot.protein = 90
        snapshot.calorieGoal = 1800
        snapshot.save(defaults: defaults)
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        let loaded = DailySnapshot.load(for: tomorrow, defaults: defaults)
        #expect(loaded.calories == 0)
        #expect(loaded.protein == 0)
        #expect(loaded.calorieGoal == 1800)
    }

    @Test func nothingSavedYetIsAnEmptyDay() {
        #expect(DailySnapshot.load(for: Date(), defaults: defaults).calories == 0)
    }
}

struct AppLinkTests {
    @Test func everyLinkRoundTrips() {
        for link in AppLink.allCases {
            #expect(AppLink(url: link.url) == link)
        }
    }

    @Test func ignoresOtherURLs() throws {
        #expect(AppLink(url: try #require(URL(string: "https://example.com/scan"))) == nil)
        #expect(AppLink(url: try #require(URL(string: "kcal://unknown"))) == nil)
    }
}

@MainActor
struct WidgetSyncTests {
    private func food(calories: Int, protein: Int = 0, servings: Int = 1, on date: Date) -> Food {
        Food(name: "Food", day: Day(date: date), protein: protein, carbohydrates: 1, fat: 2, meal: .lunch, servings: servings,
             calories_per_serving: calories, sodium: nil, sugars: nil, fiber: nil, ingredients: nil, url: nil, barcode: nil, brand: nil)
    }

    @Test func countsOnlyTodayAndUsesTheUsersGoals() throws {
        _ = try ModelContainer(for: User.self, Day.self, Food.self, Search.self, CustomFood.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let user = User(name: "Sam", calorie_goal: 1800, protein_goal: 120, carb_goal: 180, fat_goal: 60)
        let snapshot = WidgetSync.snapshot(
            foods: [food(calories: 300, protein: 20, servings: 2, on: today), food(calories: 900, on: yesterday)],
            user: user, at: Date()
        )
        #expect(snapshot.calories == 600)
        #expect(snapshot.protein == 40)
        #expect(snapshot.calorieGoal == 1800)
        #expect(snapshot.fatGoal == 60)
    }
}
