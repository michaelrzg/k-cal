//
//  PrintedFoodViews.swift
//  k-cal
//
//  Reviews what was read from a photo of packaging, before it goes on to the food sheet.
//

import SwiftUI

/// The numbers from a nutrition panel, with anything doubtful called out and everything editable.
struct NutritionLabelReview: View {
    let photo: UIImage
    /// Products the front of the package might be, offered as names.
    let choices: [FoodProduct]
    let onRetake: () -> Void
    let onUse: (FoodProduct) -> Void

    @State private var label: NutritionLabel
    @State private var name: String

    init(photo: UIImage, label: NutritionLabel, name: String = "", choices: [FoodProduct] = [],
         onRetake: @escaping () -> Void, onUse: @escaping (FoodProduct) -> Void) {
        self.photo = photo
        self.choices = choices
        self.onRetake = onRetake
        self.onUse = onUse
        _label = State(initialValue: label)
        _name = State(initialValue: name)
    }

    /// Distinct names other than the one already filled in.
    private var otherNames: [String] {
        var seen = Set([trimmedName.lowercased()])
        return choices.map(\.fullName).filter { seen.insert($0.lowercased()).inserted }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .listRowBackground(Color.clear)
            }
            if !label.isComplete {
                Section {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.brand)
                }
                .listRowBackground(Theme.card)
            }
            Section {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                if !otherNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(otherNames, id: \.self) { other in
                                Button(other) { name = other }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Food")
            } footer: {
                if !choices.isEmpty { Text("Names from the front of the package. The numbers below are from the label.") }
            }
            .listRowBackground(Theme.card)
            Section {
                amount("Calories", \.calories, unit: "kcal")
                amount("Protein", \.protein, unit: "g")
                amount("Carbs", \.carbohydrates, unit: "g")
                amount("Fat", \.fat, unit: "g")
            } header: {
                Text(servingTitle)
            } footer: {
                if let servings = label.servingsPerContainer {
                    Text("About \(servings.formatted()) servings in the package. You can set how many you had next.")
                }
            }
            .listRowBackground(Theme.card)
        }
        .themedList()
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Retake", action: onRetake)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button {
                    onUse(FoodProduct(label: label, name: trimmedName))
                } label: {
                    Text("Use Label").foregroundStyle(Theme.onBrand).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(trimmedName.isEmpty)
            }
            .padding()
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private var servingTitle: String {
        if let serving = label.serving { return "Per serving: \(serving)" }
        return label.amountGrams == 100 ? "Per 100 g" : "Per serving"
    }

    private var warning: String {
        if !label.unread.isEmpty {
            return "Couldn't read \(label.unread.joined(separator: ", ").lowercased()). Please check them against the label."
        }
        return "These numbers don't quite add up, so one may be misread. Please check them against the label."
    }

    private func amount(_ title: String, _ keyPath: WritableKeyPath<Nutrition, Double>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: Binding(get: { label.nutrition[keyPath: keyPath] }, set: { label.nutrition[keyPath: keyPath] = $0 }), format: .number.precision(.fractionLength(0 ... 1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}

/// The products a package might be, to pick from. Words on a package are never quite certain, so this always asks.
struct PackageChoices: View {
    let photo: UIImage
    let products: [FoodProduct]
    let onPick: (FoodProduct) -> Void
    /// What to offer when it's none of them.
    var otherTitle = "None of these, estimate it from the photo"
    let onOther: () -> Void

    var body: some View {
        Form {
            Section {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .listRowBackground(Color.clear)
            }
            Section("Which one is it?") {
                ForEach(products) { product in
                    Button {
                        onPick(product)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name).foregroundStyle(.primary)
                            Text(detail(product)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button(otherTitle, action: onOther)
            }
            .listRowBackground(Theme.card)
        }
        .themedList()
    }

    private func detail(_ product: FoodProduct) -> String {
        [product.brand, "\(Int(product.nutrition.calories.rounded())) kcal", product.serving]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
