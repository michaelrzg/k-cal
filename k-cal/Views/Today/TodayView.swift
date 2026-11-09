//
//  TodayView.swift
//  k-cal
//

import SwiftData
import SwiftUI

struct TodayView: View {
    @Binding var showingProfile: Bool
    @Query private var foods: [Food]
    @Query private var users: [User]
    @Query(sort: \LiftPlan.started, order: .reverse) private var plans: [LiftPlan]

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var todaysFoods: [Food] {
        foods.filter { $0.isLogged(on: today) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DaySummaryCard(foods: todaysFoods, goals: .resolved(user: users.first, plan: plans.first, on: today), caption: plans.first?.goalCaption(on: today))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                DayLog(foods: todaysFoods, date: today)
                InlineAd(unitID: HomeBottomBannerId)
            }
            .themedList()
            .contentMargins(.top, 8, for: .scrollContent)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileButton(showingProfile: $showingProfile)
                }
            }
        }
    }
}

struct ProfileButton: View {
    @Binding var showingProfile: Bool

    var body: some View {
        Button {
            showingProfile = true
        } label: {
            Image(systemName: "person.crop.circle")
        }
        .accessibilityLabel("Profile")
    }
}
