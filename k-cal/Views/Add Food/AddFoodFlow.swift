//
//  AddFoodFlow.swift
//  k-cal
//
//  Every way of adding food, reachable from any screen. It remembers which meal and day the user started
//  from, so those carry through to the review sheet.
//

import SwiftData
import SwiftUI

/// A full-screen step of adding food.
enum AddFoodRoute: Identifiable {
    case scan
    case snapMeal
    case myFoods
    /// A barcode nothing knows, for the user to fill in.
    case newCustomFood(barcode: String)

    var id: String {
        switch self {
        case .scan: "scan"
        case .snapMeal: "snapMeal"
        case .myFoods: "myFoods"
        case let .newCustomFood(barcode): "newCustomFood-\(barcode)"
        }
    }
}

@MainActor
@Observable
final class AddFoodFlow {
    struct Review: Identifiable {
        let id = UUID()
        let food: Food
        let date: Date
    }

    struct Failure: Identifiable {
        let id = UUID()
        let message: String
        var unknownBarcode: String?
    }

    var route: AddFoodRoute?
    var review: Review?
    var failure: Failure?
    private(set) var isLookingUp = false
    /// Goes up with each food saved, so the screen showing it can react.
    private(set) var savedCount = 0
    /// Goes up with each request to search, which the tab bar answers.
    private(set) var searchRequests = 0

    private var meal: Meal?
    private var date: Date?
    private var pendingFood: ((Day, Meal) -> Food)?
    private var pendingBarcode: String?
    private var hasPendingSearch = false
    private let repository = FoodRepository.shared

    /// Starts a route. With no meal or day given, it's for now.
    func start(_ route: AddFoodRoute, meal: Meal? = nil, date: Date? = nil) {
        self.meal = meal
        self.date = date
        self.route = route
    }

    func startSearch(meal: Meal? = nil, date: Date? = nil) {
        self.meal = meal
        self.date = date
        searchRequests += 1
        hasPendingSearch = true
    }

    /// True once for each request, so a tab opening for the first time can still answer it.
    func consumePendingSearch() -> Bool {
        defer { hasPendingSearch = false }
        return hasPendingSearch
    }

    /// Called from a full-screen step: the sheet opens once that step is gone.
    func reviewAfterRoute(_ product: FoodProduct) {
        pendingFood = { day, meal in Food(product: product, day: day, meal: meal) }
    }

    func reviewAfterRoute(estimate: MealEstimate, name: String) {
        pendingFood = { day, meal in Food(estimate: estimate, name: name, day: day, meal: meal) }
    }

    func scanned(_ barcode: String) {
        pendingBarcode = barcode
        route = nil
    }

    func routeDismissed(customFoods: [CustomFood]) {
        if let barcode = pendingBarcode {
            pendingBarcode = nil
            lookUp(barcode, customFoods: customFoods)
        } else if let makeFood = pendingFood {
            pendingFood = nil
            open(makeFood)
        }
    }

    func review(_ product: FoodProduct) {
        open { day, meal in Food(product: product, day: day, meal: meal) }
    }

    func logAgain(_ logged: Food) {
        open { day, meal in Food(copying: logged, day: day, meal: meal) }
    }

    func didSave() {
        savedCount += 1
        meal = nil
        date = nil
    }

    /// Custom foods come first, so a product entered once is found offline and overrides the databases.
    private func lookUp(_ barcode: String, customFoods: [CustomFood]) {
        if let custom = customFoods.first(where: { $0.hasBarcode(barcode) }) {
            review(custom.product)
            return
        }
        isLookingUp = true
        Task {
            do {
                if let product = try await repository.product(barcode: barcode) {
                    review(product)
                } else {
                    failure = Failure(message: "Add it as a custom food and it will be found next time.", unknownBarcode: barcode)
                }
            } catch {
                failure = Failure(message: error.localizedDescription)
            }
            isLookingUp = false
        }
    }

    private func open(_ makeFood: (Day, Meal) -> Food) {
        let day = Calendar.current.startOfDay(for: date ?? Date())
        let meal = meal ?? Meal(hour: Calendar.current.component(.hour, from: Date()))
        // The Day is a placeholder: the sheet files the food under the right one when it's saved.
        review = Review(food: makeFood(Day(date: day), meal), date: day)
    }
}

/// Presents the flow over whichever screen is showing.
struct AddFoodPresenter: ViewModifier {
    @Bindable var flow: AddFoodFlow
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $flow.route, onDismiss: { flow.routeDismissed(customFoods: customFoods) }) { route in
                switch route {
                case .scan:
                    BarcodeScannerScreen(onCode: flow.scanned)
                case .snapMeal:
                    SnapMealView(onUse: flow.reviewAfterRoute(estimate:name:), onProduct: flow.reviewAfterRoute)
                case .myFoods:
                    MyFoodsView(onPick: flow.reviewAfterRoute)
                case let .newCustomFood(barcode):
                    CustomFoodEditor(barcode: barcode) { flow.reviewAfterRoute($0.product) }
                }
            }
            .sheet(item: $flow.review) { review in
                FoodEntrySheet(food: review.food, mode: .add(date: review.date)) { flow.didSave() }
            }
            .alert(item: $flow.failure) { failure in
                if let barcode = failure.unknownBarcode {
                    Alert(
                        title: Text("Product not found"),
                        message: Text(failure.message),
                        primaryButton: .default(Text("Add Food")) { flow.route = .newCustomFood(barcode: barcode) },
                        secondaryButton: .cancel(Text("Scan Again")) { flow.route = .scan }
                    )
                } else {
                    Alert(title: Text("Lookup failed"), message: Text(failure.message), dismissButton: .default(Text("OK")))
                }
            }
            .overlay {
                if flow.isLookingUp {
                    ProgressView("Looking it up...")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                }
            }
    }
}
