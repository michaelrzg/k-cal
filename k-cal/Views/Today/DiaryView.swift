//
//  DiaryView.swift
//  k-cal
//

import SwiftData
import SwiftUI

struct DiaryView: View {
    @Binding var showingProfile: Bool
    @Query private var foods: [Food]
    @Query private var users: [User]
    @State private var date = Calendar.current.startOfDay(for: Date())
    @State private var showingCalendar = false

    private var daysFoods: [Food] {
        foods.filter { $0.isLogged(on: date) }
    }

    private var title: String {
        Calendar.current.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.wide).month().day())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    dateBar
                    if showingCalendar {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Theme.brand)
                    }
                }
                .listRowBackground(Theme.card)
                Section {
                    DaySummaryCard(foods: daysFoods, user: users.first)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                DayLog(foods: daysFoods, date: date)
                InlineAd(unitID: DiaryBottomBannerId)
            }
            .themedList()
            .navigationTitle("Diary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileButton(showingProfile: $showingProfile)
                }
            }
        }
    }

    private var dateBar: some View {
        HStack {
            step(-1, symbol: "chevron.left", label: "Previous day")
            Spacer()
            Button {
                withAnimation { showingCalendar.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(title).font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .rotationEffect(.degrees(showingCalendar ? 180 : 0))
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.borderless)
            Spacer()
            step(1, symbol: "chevron.right", label: "Next day")
        }
    }

    private func step(_ days: Int, symbol: String, label: String) -> some View {
        Button {
            date = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        } label: {
            Image(systemName: symbol).frame(width: 36, height: 28)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}
