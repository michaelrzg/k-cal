import SwiftUI

struct AddFoodSheet: View {
    @Bindable var food: Food
    @Environment(\ .dismiss) var dismiss
    @Environment(\ .modelContext) var context
    @Binding var selectedTab: Int
    @State var calorie_per_serving_string: String
    let mealOptions = ["Breakfast", "Lunch", "Dinner", "Snack"]

    // Store per-serving macronutrient values
    @State private var proteinPerServing: Int
    @State private var carbsPerServing: Int
    @State private var fatPerServing: Int

    init(food: Food, selectedTab: Binding<Int>) {
        self.food = food
        _calorie_per_serving_string = State(initialValue: "\(food.calories_per_serving)")
        _proteinPerServing = State(initialValue: food.protein / (food.servings > 0 ? food.servings : 1))
        _carbsPerServing = State(initialValue: food.carbohydrates / (food.servings > 0 ? food.servings : 1))
        _fatPerServing = State(initialValue: food.fat / (food.servings > 0 ? food.servings : 1))
        _selectedTab = selectedTab
    }

    var body: some View {
        NavigationStack {
            Form {
                Section{
                    HStack{
                        if let url = URL(string: food.url){
                            AsyncImage(url: url) { image in
                                image.resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame( height: 200)
                                    .overlay(ProgressView())
                            }
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }.listSectionSpacing(5)

                if let day = food.day {
                    DatePicker("Date", selection: Binding(
                        get: { day.date },
                        set: { food.day?.date = $0 }
                    ))
                }
                HStack {
                    Text("Name:").frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    TextField("Name:", text: $food.name).multilineTextAlignment(.trailing)
                }

                Picker("Meal:", selection: $food.meal) {
                    ForEach(mealOptions, id: \ .self) { meal in
                        Text(meal).tag(meal)
                    }
                }
                .pickerStyle(.menu)

                Picker("Servings:", selection: $food.servings) {
                    ForEach(1 ... 100, id: \ .self) { number in
                        Text("\(number)")
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: food.servings) { newValue in
                    food.calories = (Int(calorie_per_serving_string) ?? 0) * newValue
                    food.protein = proteinPerServing * newValue
                    food.carbohydrates = carbsPerServing * newValue
                    food.fat = fatPerServing * newValue
                }

                HStack {
                    Text("Calories / Serving:")
                    Spacer()
                    TextField("k-cal", text: $calorie_per_serving_string)
                        .keyboardType(.numberPad)
                        .onChange(of: calorie_per_serving_string) { newValue in
                            if let newCalories = Int(newValue) {
                                food.calories_per_serving = newCalories
                                food.calories = newCalories * food.servings
                            }
                        }
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Spacer()
                    VStack {
                        Text("Protein").foregroundStyle(Color("Protein"))
                        TextField("g", value: $food.protein, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 50)
                    }
                    Spacer()
                    VStack {
                        Text("Carbs").foregroundStyle(Color("Carbohydrate"))
                        TextField("g", value: $food.carbohydrates, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 50)
                    }
                    Spacer()
                    VStack {
                        Text("Fat").foregroundStyle(Color("Fat"))
                        TextField("g", value: $food.fat, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 50)
                    }
                    Spacer()
                }
                // Macronutrient Circle Chart
                VStack {
                    MacronutrientRingView(fat: food.fat, protein: food.protein, carbs: food.carbohydrates, calories: food.calories)
                        .frame(width: 150, height: 150)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                // Additional Nutrients
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Sodium:")
                        Spacer()
                        Text(food.sodium > 0 ? "\(food.sodium * food.servings) mg" : "-")
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Sugar:")
                        Spacer()
                        Text(food.sugars > 0 ? "\(food.sugars * food.servings) g" : "-")
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fiber:")
                        Spacer()
                        Text(food.fiber > 0 ? "\(food.fiber * food.servings) g" : "-")
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(.top, 10)

                // Ingredients Section
                Section(header: Text("Ingredients")) {
                    ScrollView {
                        Text(food.ingredients ?? "No ingredients available")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle("\(food.name)")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") {
                        print("Saving...")
                        dismiss()
                        selectedTab = 0
                    }
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Cancel") {
                        print("Cancel...")
                        context.delete(food)
                        dismiss()
                        selectedTab = 1
                    }
                }
            }.gesture(
                DragGesture()
                    .onEnded { _ in

                        print("Cancel...")
                        context.delete(food)
                        dismiss()
                        selectedTab = 1
                    }
            )
        }
    }
}
