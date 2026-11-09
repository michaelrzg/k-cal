//
//  ProfileView.swift
//  k-cal
//

import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @Query(sort: \LiftPlan.started, order: .reverse) private var plans: [LiftPlan]

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    if let user = users.first {
                        UserSections(user: user, followsTraining: plans.first?.matchesNutrition == true)
                    }
                    FoodDatabaseSection()
                    Section {
                        NavigationLink("Acknowledgements") { AcknowledgementsView() }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .themedList()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? context.save()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

private struct UserSections: View {
    @Bindable var user: User
    let followsTraining: Bool

    var body: some View {
        Section {
            HStack(spacing: 14) {
                Text(user.name.prefix(1).uppercased())
                    .font(.numeral(24))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Theme.brand, in: Circle())
                TextField("Your name", text: $user.name).font(.title3.weight(.semibold))
            }
        }
        Section {
            goal("Calories", $user.calorie_goal, unit: "cal")
            goal("Protein", $user.protein_goal, unit: "g", color: Theme.protein)
            goal("Carbs", $user.carb_goal, unit: "g", color: Theme.carbohydrate)
            goal("Fat", $user.fat_goal, unit: "g", color: Theme.fat)
        } header: {
            Text("Daily goals")
        } footer: {
            if followsTraining {
                Text("Your Lifts plan is setting your daily goals. These are kept for when you turn that off.")
            }
        }
    }

    private func goal(_ title: String, _ value: Binding<Int>, unit: String, color: Color = .primary) -> some View {
        HStack {
            Text(title).foregroundStyle(color)
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary).frame(width: 24, alignment: .leading)
        }
    }
}

private struct AcknowledgementsView: View {
    private var text: String {
        Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    var body: some View {
        ScrollView {
            Text(text).font(.footnote).padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
