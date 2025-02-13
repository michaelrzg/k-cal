import SwiftUI

struct UpdateFoodSheet: View {
    @Bindable var food: Food
    @State var servings: Int = 1
    @Environment(\.dismiss) var dismiss
    
    @State var calorie_string: String = ""
    @State var calorie_per_serving_string: String

    init(food: Food) {
        self.food = food
        _calorie_per_serving_string = State(initialValue: "\(food.calories_per_serving)") // Initialize with food.calories_per_serving
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $food.day.date)
                
                HStack {
                    Text("Name:").frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    TextField("Name:", text: $food.name).multilineTextAlignment(.trailing)
                }
                
                Picker("Servings:", selection: $food.servings) {
                    ForEach(1...100, id: \.self) { number in
                        Text("\(number)")
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: food.servings) { newValue in
                    food.calories = (Int(calorie_per_serving_string) ?? 0) * newValue
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
                        .padding(.bottom,20)
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)


            }
            .navigationTitle("Update \(food.name)")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") {
                        print("Saving...")
                        dismiss()
                    }
                }
            }
        }
    }
}

// Macronutrient Circle Chart
struct MacronutrientRingView: View {
    var fat: Int
    var protein: Int
    var carbs: Int
    var calories: Int
    
    var total: CGFloat {
        CGFloat(fat + protein + carbs)
    }
    
    var fatRatio: CGFloat {
        total > 0 ? CGFloat(fat) / total : 0
    }
    
    var proteinRatio: CGFloat {
        total > 0 ? CGFloat(protein) / total : 0
    }
    
    var carbsRatio: CGFloat {
        total > 0 ? CGFloat(carbs) / total : 0
    }

    var body: some View {
        ZStack {
            // Base Circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 15)
            
            // Fat - Purple
            Circle()
                .trim(from: 0, to: fatRatio)
                .stroke(Color("Fat"), lineWidth: 15)
                .rotationEffect(.degrees(-90))
            
            // Protein - Yellow
            Circle()
                .trim(from: fatRatio, to: fatRatio + proteinRatio)
                .stroke(Color("Protein"), lineWidth: 15)
                .rotationEffect(.degrees(-90))
            
            // Carbs - Blue
            Circle()
                .trim(from: fatRatio + proteinRatio, to: 1)
                .stroke(Color("Carbohydrate"), lineWidth: 15)
                .rotationEffect(.degrees(-90))
            
            // Calorie Label
            VStack {
                Text("\(calories)")
                    .font(.system(size: 30, weight: .bold))
                Text("cal")
                    .font(.system(size: 14, weight: .regular))
            }
        }
    }
}

#Preview {
    UpdateFoodSheet(food: Food(name: "Zaxby's", day: Day(date: Date()), protein: 10, carbohydrates: 20, fat: 10, meal: .lunch, servings: 1, calories_per_serving: 1500))
}
