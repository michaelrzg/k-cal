//
//  MultiStepView.swift
//  k-cal
//
//  Created by Michael Rizig on 2/17/25.
//


import SwiftUI

struct WeightScale: View {
    @State private var step = 0
    @State private var isBouncing = true
    @Binding private var next_disabled: Bool
    @Binding private var user: User
    @State private var selectedCalories: Int = 2000  // Default starting value
   @State private var selectedCaloriesString: String = "2000"
    @State private var selectedActivityLevel: ActivityLevel = .lightlyActive // Default activity level

    var calorieGoals: [Int] {
        return stride(from: 1500, to: 5050, by: 50).map { $0 }
    }
    @State private var title_opacity = 1.0
    @State private var activity_opacity = 1.0
    @State private var calories_opacity = 1.0
    @State private var protein_opacity = 1.0
    @State private var protein: Int = 0 // Protein value (grams)
      @State private var carbs: Int = 0 // Carbs value (grams)
      @State private var fat: Int = 0 // Fat value (grams)
        var body: some View {
            // Custom Title Bar
                       
            VStack {
                HStack {
                    Text("Tell me about your goals.")
                        .font(.title) // Make the title large
                        .bold()  // Make it bold for a better effect
                        .padding(.leading, 20)
                        .opacity(title_opacity)
                    Spacer() // To push the title to the left
                }
                .padding(.top, 40).offset(y:-40)
                ZStack{
                    // Base of the scale
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .shadow(radius: 10).scaleEffect(3)
                    ZStack {
                        // The round scale dial
                        Circle()
                            .stroke(lineWidth: 6)
                            .foregroundColor(Color.gray.opacity(0.5))
                            .frame(width: 160, height: 160)
                        
                        // Dial background
                        Circle()
                            .fill(Color.white)
                            .frame(width: 140, height: 140)
                        
                        // Scale numbers (representing weight values)
                        ForEach(0..<12, id: \.self) { i in
                            Text("\(i * 10)")
                                .font(.caption)
                                .foregroundColor(.black)
                                .rotationEffect(.degrees(Double(i) * 30)) // 360 / 12 numbers = 30 degrees between each
                                .offset(x: 60, y: -75)
                                .rotationEffect(.degrees(Double(i) * 30))
                        }.scaleEffect(0.6)
                        
                        // The needle of the scale (animated)
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 4, height: 50)
                            .offset(y: -40)
                            .rotationEffect(.degrees(isBouncing ? 30 : -30)) // Needle bouncing between 15 and -15 degrees
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isBouncing)
                        
                        // Center circle (to give it a real dial look)
                        Circle()
                            .fill(Color.black)
                            .frame(width: 20, height: 20)
                    }
                    .frame(width: 200, height: 200)
                    .offset(y:-180)
                }.scaleEffect(0.3)
                    .offset(y:-45)
                    .opacity(title_opacity)
                HStack{
                    
                }.frame(maxHeight: 50)
                // Activity Level Picker
                HStack{
                    Text("Select your activity level:")
                        .font(.title3) // Make the title large
                        .bold()  // Make it bold for a better effect
                        .padding(.leading, 20).offset(y:-100)
                    Spacer()
                }.opacity(activity_opacity)
             
                Picker("Select Activity Level", selection: $selectedActivityLevel) {
                               ForEach(ActivityLevel.allCases, id: \.self) { level in
                                   Text(level.rawValue)
                                       .tag(level)
                               }
                           }
                           .pickerStyle(SegmentedPickerStyle())
                           .padding(.horizontal).offset(y:-100)
                           .opacity(activity_opacity)
                VStack{
                
                    HStack {
                        Text("Choose your calorie goal:")
                            .font(.title3)
                            .bold()
                            .padding(.leading, 20)
                            .offset(y: -90)
                        
                        Spacer()
                        
                        TextField("Calories", text: $selectedCaloriesString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8) // Reduce vertical padding to make it shorter
                            .padding(.horizontal, 10) // Keep horizontal padding for spacing
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.8), lineWidth: 1.5) // Slightly thinner border
                            )
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        hideKeyboard()
                                    }
                                }
                            }
                            .frame(width: 80, height: 35) // Control width & explicitly set height
                            .padding(.trailing, 20)
                            .offset(y: -90)

                    }
                    .opacity(calories_opacity)
                                
                               
                                
                }.padding(.bottom,10)
                    .onChange(of: selectedCalories){
                        updateMacronutrients(for: selectedCalories, activityLevel: selectedActivityLevel)


                    }
           
               
                         
                HStack {
                               Spacer()
                               VStack {
                                   Text("Protein")
                                       .foregroundStyle(Color("Protein"))
                                   TextField("g", value: $protein, format: .number)
                                       .keyboardType(.numberPad)
                                       .multilineTextAlignment(.center)
                                       .frame(width: 50)
                                       .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                                       .overlay(
                                           RoundedRectangle(cornerRadius: 8)
                                               .stroke(Color.blue.opacity(0.8), lineWidth: 1.5) // Slightly thinner border
                                       )
                                       .onChange(of: protein) { newValue in
                                           // Handle any additional logic or validation for protein here
                                       }
                               }
                               Spacer()
                               VStack {
                                   Text("Carbs")
                                       .foregroundStyle(Color("Carbohydrate"))
                                   TextField("g", value: $carbs, format: .number)
                                       .keyboardType(.numberPad)
                                       .multilineTextAlignment(.center)
                                       .frame(width: 50)
                                       .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                                       .overlay(
                                           RoundedRectangle(cornerRadius: 8)
                                               .stroke(Color.blue.opacity(0.8), lineWidth: 1.5) // Slightly thinner border
                                       )
                                       .onChange(of: carbs) { newValue in
                                           // Handle any additional logic or validation for carbs here
                                       }
                               }
                               Spacer()
                               VStack {
                                   Text("Fat")
                                       .foregroundStyle(Color("Fat"))
                                   TextField("g", value: $fat, format: .number)
                                       .keyboardType(.numberPad)
                                       .multilineTextAlignment(.center)
                                       .frame(width: 50)
                                       .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                                       .overlay(
                                           RoundedRectangle(cornerRadius: 8)
                                               .stroke(Color.blue.opacity(0.8), lineWidth: 1.5) // Slightly thinner border
                                       )
                                       .onChange(of: fat) { newValue in
                                           // Handle any additional logic or validation for fat here
                                       }
                               }
                               Spacer()
                           }
                .offset(y:-90)
                .opacity(protein_opacity)
                
                MacronutrientRingView(fat: fat, protein: protein, carbs: carbs, calories: selectedCalories)
                    .offset(y:-60)
                    .opacity(protein_opacity)
                           
            }            .onChange(of: selectedCalories){
                updateMacronutrients(for: selectedCalories, activityLevel: selectedActivityLevel)
            }
            .onChange(of: selectedActivityLevel){
                updateMacronutrients(for: selectedCalories, activityLevel: selectedActivityLevel)
            }
            .onChange(of: selectedActivityLevel) { _ in
                            updateCaloriesBasedOnActivityLevel()
            }.onAppear(){
                isBouncing.toggle()
                updateMacronutrients(for: selectedCalories, activityLevel: selectedActivityLevel)
                update_user_profile()
            }
            .onChange(of: selectedCaloriesString){ value in
                if let newCalories = Int(value) {
                selectedCalories = newCalories
                }
                
            }

           
        
    }
    func updateMacronutrients(for calories: Int, activityLevel: ActivityLevel) {
           let (proteinPercentage, carbsPercentage, fatPercentage) = getMacronutrientRatios(for: activityLevel)
           
            protein = Int(Double(calories) * proteinPercentage / 4) // Protein has 4 calories per gram
              carbs = Int(Double(calories) * carbsPercentage / 4)   // Carbs have 4 calories per gram
              fat = Int(Double(calories) * fatPercentage / 9)
        update_user_profile()
       }
    func getMacronutrientRatios(for activityLevel: ActivityLevel) -> (Double, Double, Double) {
            switch activityLevel {
            case .lightlyActive:
                return (0.20, 0.55, 0.25)
            case .moderatelyActive:
                return (0.25, 0.55, 0.20)
            case .veryActive:
                return (0.30, 0.50, 0.20)
            }
        update_user_profile()
        }
    func updateCaloriesBasedOnActivityLevel() {
        switch selectedActivityLevel {
        case .lightlyActive:
            selectedCalories = 2000
        case .moderatelyActive:
            selectedCalories = 2500
        case .veryActive:
            selectedCalories = 3000
        }
        update_user_profile()
    }
    func update_user_profile(){
        user.calorie_goal = selectedCalories
        user.carb_goal = carbs
        user.protein_goal = protein
        user.fat_goal = fat
    }
    init(next_disabled: Binding<Bool>, user: Binding<User>)
    {
        self._next_disabled = next_disabled
        self._user = user
    }
    
}
// Enum to define activity levels
enum ActivityLevel: String, CaseIterable {
    case lightlyActive = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Very Active"
}

#Preview {
    @State var b = false
    @State var user: User = User(name: "", calorie_goal: 0, protein_goal: 0, carb_goal: 0, fat_goal: 0)

    WeightScale(next_disabled: $b, user: $user)
}
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
