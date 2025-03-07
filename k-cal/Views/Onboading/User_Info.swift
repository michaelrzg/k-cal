import SwiftUI
import SDWebImageSwiftUI


struct User_Info: View {
    @State private var title_opacity = 1.0
    @State private var name = ""
    @State private var age = ""
    @State private var gender: GenderOption = .male
    @FocusState private var isFocused: Bool
    @Binding private var user: User
    @Binding private var next_disabled: Bool

    var body: some View {
        VStack {
            HStack {
                Text("First things first.")
                    .font(.title)
                    .bold()
                    .padding(.leading, 20)
                    .opacity(title_opacity)
                Spacer()
            }

            AnimatedImage(name: "waitamin.gif")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.gray.opacity(0.3), lineWidth: 2))
                .shadow(radius: 5)

            HStack {
                Text("Who are you?")
                    .font(.title)
                    .bold()
                    .padding(.leading, 20)
                    .opacity(title_opacity)
                    .focused($isFocused)
                    .offset(y: 10)
                Spacer()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isFocused = true
                }
                next_disabled = true
            }

            VStack(alignment: .leading, spacing: 10) {
                
                TextField("Enter your name", text: $name)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.6), lineWidth:2)
                    )
                    .padding(.horizontal).background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6))).padding(.horizontal)
                Text("What are you?")
                    .font(.title)
                    .bold()
                    .opacity(title_opacity)
                    .focused($isFocused)
                    .offset(y: 10)
                    .padding(.bottom,15)
                Picker("Select Gender", selection: $gender) {
                    ForEach(GenderOption.allCases, id: \.self) { genderOption in
                        Text(genderOption.rawValue)
                            .tag(genderOption)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                .padding(.vertical, 8)
                
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .onChange(of: name) {
            user.name = name
            updateNextButtonState()
        }
        .onChange(of: age) {
            updateNextButtonState()
        }
        .onChange(of: gender){
            updateNextButtonState()
        }
    }

    func updateNextButtonState() {
        if name.isEmpty {
            next_disabled = true
        } else {
            next_disabled = false
        }
    }

    init(user: Binding<User>, next_disabled: Binding<Bool>) {
        self._user = user
        self._next_disabled = next_disabled
    }
}

#Preview {
    @State var b = false
    @State var user: User = User(name: "", calorie_goal: 0, protein_goal: 0, carb_goal: 0, fat_goal: 0)
    User_Info(user: $user, next_disabled: $b)
}
enum GenderOption: String, CaseIterable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Other"
}
