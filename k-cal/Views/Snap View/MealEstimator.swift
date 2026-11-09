//
//  MealEstimator.swift
//  k-cal
//
//  Runs the two on-device models on a meal photo. Nothing leaves the phone.
//

import CoreML
import UIKit
import Vision

struct MealPhotoResult: Equatable {
    /// The plate model's own estimate.
    let estimate: MealEstimate
    /// False when Vision is confident the photo doesn't show food.
    let looksLikeFood: Bool
    /// Database foods for the likely dishes, best first.
    var matches: [DishMatch] = []

    /// The match to start from. Only a single food has one: for a meal, the plate model's own macros did better
    /// than any one dish's, even with the classifier 90% sure of the dish.
    var preferredMatch: DishMatch? {
        matches.first { $0.dish == estimate.dishes.first && $0.itemGrams != nil }
    }
}

enum MealEstimatorError: LocalizedError {
    case unreadablePhoto
    case unusableOutput

    var errorDescription: String? {
        switch self {
        case .unreadablePhoto: "That photo couldn't be read."
        case .unusableOutput: "The photo couldn't be estimated."
        }
    }
}

/// The models are large, so they load on first use and go away with this object.
actor MealEstimator {
    private static let plateSize = CGSize(width: 384, height: 384)
    private static let dishSize = CGSize(width: 288, height: 288)
    private static let dishGuesses = 3
    /// Measured with this Vision classifier: 2.8% of 1,000 Food-101 photos fall below it, as did 11 of 11 others.
    private static let minimumFoodConfidence: Float = 0.05

    /// What the plate model's ingredient output stands for, in order.
    private static let ingredientNames: [String] = {
        guard let url = Bundle.main.url(forResource: "plate_ingredients", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }()

    private var plateModel: MealPlate?
    private var dishModel: DishClassifier?

    func analyze(_ photo: UIImage) async throws -> MealPhotoResult {
        guard let squared = Self.render(photo, size: Self.plateSize, mode: .stretch),
              let cropped = Self.render(photo, size: Self.dishSize, mode: .fill)
        else { throw MealEstimatorError.unreadablePhoto }

        let plate = try loadPlateModel()
        let dish = try loadDishModel()
        let reading = try await plate.prediction(input: MealPlateInput(imageWith: squared))
        let logTotals = reading.logTotals
        let probabilities = try await dish.prediction(input: DishClassifierInput(imageWith: cropped)).classLabel_probs

        let dishes = probabilities
            .sorted { $0.value > $1.value }
            .prefix(Self.dishGuesses)
            .map { DishGuess(label: $0.key, confidence: $0.value) }
        let values = (0 ..< logTotals.count).map { logTotals[$0].doubleValue }
        guard var estimate = MealEstimate(logTotals: values, dishes: dishes) else {
            throw MealEstimatorError.unusableOutput
        }
        let chances = (0 ..< reading.ingredients.count).map { 1 / (1 + exp(-reading.ingredients[$0].doubleValue)) }
        estimate.ingredients = MealEstimate.likelyIngredients(chances, names: Self.ingredientNames)
        var matches = estimate.suggestions.compactMap { dish in
            DishFoods.food(for: dish.label).map { DishMatch(dish: dish, food: $0) }
        }
        let labels = Self.visionLabels(cropped)
        // The dish classifier's guesses are noise for fruit, so they aren't offered alongside it.
        if let fruit = WholeFood.guess(labels: labels ?? [:], estimatedCalories: estimate.calories).flatMap(DishFoods.match(for:)) {
            estimate.dishes = [fruit.dish]
            matches = [fruit]
        }
        let looksLikeFood = labels.map { ($0["food"] ?? 0) >= Self.minimumFoodConfidence } ?? true
        return MealPhotoResult(estimate: estimate, looksLikeFood: looksLikeFood, matches: matches)
    }

    private func loadPlateModel() throws -> MealPlate {
        if let plateModel { return plateModel }
        let model = try MealPlate(configuration: MLModelConfiguration())
        plateModel = model
        return model
    }

    private func loadDishModel() throws -> DishClassifier {
        if let dishModel { return dishModel }
        let model = try DishClassifier(configuration: MLModelConfiguration())
        dishModel = model
        return model
    }

    /// Nil if Vision fails, as it does on every call in the Simulator, where this classifier can't run. Its labels only
    /// add to the estimate, so that's never an error.
    private static func visionLabels(_ image: CGImage) -> [String: Float]? {
        let request = VNClassifyImageRequest()
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil, let results = request.results else { return nil }
        return Dictionary(results.map { ($0.identifier, $0.confidence) }, uniquingKeysWith: max)
    }

    private enum RenderMode {
        /// Squashed to fit, keeping everything in the photo: what the plate model trained on.
        case stretch
        /// Aspect kept, centre-cropped: what the dish classifier trained on.
        case fill
    }

    /// Draws through UIKit so the photo's EXIF orientation is applied.
    private static func render(_ photo: UIImage, size: CGSize, mode: RenderMode) -> CGImage? {
        guard photo.size.width > 0, photo.size.height > 0 else { return nil }
        let scale = max(size.width / photo.size.width, size.height / photo.size.height)
        let drawn = mode == .stretch ? size : CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
        let origin = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            photo.draw(in: CGRect(origin: origin, size: drawn))
        }.cgImage
    }
}
