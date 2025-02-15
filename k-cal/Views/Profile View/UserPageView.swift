import SwiftUI
import SwiftData

struct UserPageView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @State private var isEditing = false

    private var user: User? { users.first }

    var body: some View {
        NavigationView {
            Form {
                if let user = user {
                    Section(header: Text("User Information")) {
                        HStack {
                            Text("Name:")
                            Spacer()
                            if isEditing {
                                TextField("Name", text: Binding(
                                    get: { user.name },
                                    set: { newValue in
                                        user.name = newValue
                                    }
                                ))
                            } else {
                                Text(user.name)
                            }
                        }
                        HStack {
                            Text("Calorie Goal:")
                            Spacer()
                            if isEditing {
                                TextField("Calorie Goal", value: Binding(
                                    get: { user.calorie_goal },
                                    set: { newValue in
                                        user.calorie_goal = newValue
                                    }
                                ), format: .number)
                                .keyboardType(.numberPad)
                            } else {
                                Text("\(user.calorie_goal)")
                            }
                        }
                        HStack {
                            Text("Protein Goal:")
                            Spacer()
                            if isEditing {
                                TextField("Protein Goal", value: Binding(
                                    get: { user.protein_goal },
                                    set: { newValue in
                                        user.protein_goal = newValue
                                    }
                                ), format: .number)
                                .keyboardType(.numberPad)
                            } else {
                                Text("\(user.protein_goal)")
                            }
                        }
                        HStack {
                            Text("Carb Goal:")
                            Spacer()
                            if isEditing {
                                TextField("Carb Goal", value: Binding(
                                    get: { user.carb_goal },
                                    set: { newValue in
                                        user.carb_goal = newValue
                                    }
                                ), format: .number)
                                .keyboardType(.numberPad)
                            } else {
                                Text("\(user.carb_goal)")
                            }
                        }
                        HStack {
                            Text("Fat Goal:")
                            Spacer()
                            if isEditing {
                                TextField("Fat Goal", value: Binding(
                                    get: { user.fat_goal },
                                    set: { newValue in
                                        user.fat_goal = newValue
                                    }
                                ), format: .number)
                                .keyboardType(.numberPad)
                            } else {
                                Text("\(user.fat_goal)")
                            }
                        }
                    }
                } else {
                    Text("No user found. Please add a user.")
                }
            }
            .navigationTitle("User Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            do {
                                try context.save()
                                isEditing = false
                            } catch {
                                print("Error saving user data: \(error)")
                                // Consider showing an alert to the user
                            }
                        } else {
                            isEditing = true
                        }
                    }
                }
            }
        }
    }
}
#Preview {

    UserPageView()
}
