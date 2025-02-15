//
//  CreateUserView.swift
//  k-cal
//
//  Created by Michael Rizig on 2/13/25.
//

import SwiftData
import SwiftUI

struct CreateUserView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) var dismiss // To dismiss the view after creating the user

    @State private var name: String = ""
    @State private var calorieGoal: String = "" // Use String for TextField input
    @State private var proteinGoal: String = ""
    @State private var carbGoal: String = ""
    @State private var fatGoal: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Information")) {
                    TextField("Name", text: $name)
                    TextField("Calorie Goal", text: $calorieGoal)
                        .keyboardType(.numberPad)
                    TextField("Protein Goal", text: $proteinGoal)
                        .keyboardType(.numberPad)
                    TextField("Carb Goal", text: $carbGoal)
                        .keyboardType(.numberPad)
                    TextField("Fat Goal", text: $fatGoal)
                        .keyboardType(.numberPad)
                }

                Button("Create User") {
                    createUser()
                }
                .disabled(name.isEmpty || calorieGoal.isEmpty || proteinGoal.isEmpty || carbGoal.isEmpty || fatGoal.isEmpty) // Disable button if any field is empty
            }
            .navigationTitle("Create User")
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createUser() {
        guard let calorieGoalInt = Int(calorieGoal),
              let proteinGoalInt = Int(proteinGoal),
              let carbGoalInt = Int(carbGoal),
              let fatGoalInt = Int(fatGoal)
        else {
            alertMessage = "Please enter valid numbers for goals."
            showingAlert = true
            return // Exit early if conversion fails
        }

        let newUser = User(name: name, calorie_goal: calorieGoalInt, protein_goal: proteinGoalInt, carb_goal: carbGoalInt, fat_goal: fatGoalInt)

        context.insert(newUser)

        do {
            try context.save()
            dismiss() // Dismiss the view after successful creation
        } catch {
            print("Error saving user: \(error)")
            alertMessage = "Error creating user. Please try again."
            showingAlert = true
        }
    }
}
