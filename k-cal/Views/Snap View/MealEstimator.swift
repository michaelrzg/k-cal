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
    let estimate: MealEstimate
    /// False when Vision is confident the photo doesn't show food.
    let looksLikeFood: Bool
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
    private static let portionSize = CGSize(width: 504, height: 378)
    private static let dishSize = CGSize(width: 288, height: 288)
    /// The ImageNet mean, which is what the portion model was trained to see in the bars around a photo.
    private static let letterboxColor = UIColor(red: 0.485, green: 0.456, blue: 0.406, alpha: 1)
    private static let dishGuesses = 3
    /// Measured with this Vision classifier: 2.8% of 1,000 Food-101 photos fall below it, as did 11 of 11 others.
    private static let minimumFoodConfidence: Float = 0.05

    private var portionModel: MealPortion?
    private var dishModel: DishClassifier?

    func analyze(_ photo: UIImage) async throws -> MealPhotoResult {
        guard let fitted = Self.render(photo, size: Self.portionSize, mode: .fit),
              let cropped = Self.render(photo, size: Self.dishSize, mode: .fill)
        else { throw MealEstimatorError.unreadablePhoto }

        let portion = try loadPortionModel()
        let dish = try loadDishModel()
        let logTotals = try await portion.prediction(input: MealPortionInput(imageWith: fitted)).logTotals
        let probabilities = try await dish.prediction(input: DishClassifierInput(imageWith: cropped)).classLabel_probs

        let dishes = probabilities
            .sorted { $0.value > $1.value }
            .prefix(Self.dishGuesses)
            .map { DishGuess(label: $0.key, confidence: $0.value) }
        let values = (0 ..< logTotals.count).map { logTotals[$0].doubleValue }
        guard let estimate = MealEstimate(logTotals: values, dishes: dishes) else {
            throw MealEstimatorError.unusableOutput
        }
        return MealPhotoResult(estimate: estimate, looksLikeFood: Self.looksLikeFood(cropped))
    }

    private func loadPortionModel() throws -> MealPortion {
        if let portionModel { return portionModel }
        let model = try MealPortion(configuration: MLModelConfiguration())
        portionModel = model
        return model
    }

    private func loadDishModel() throws -> DishClassifier {
        if let dishModel { return dishModel }
        let model = try DishClassifier(configuration: MLModelConfiguration())
        dishModel = model
        return model
    }

    /// Only a warning, so a Vision failure counts as food rather than blocking the estimate. That includes
    /// every call in the Simulator, where this classifier can't run.
    private static func looksLikeFood(_ image: CGImage) -> Bool {
        let request = VNClassifyImageRequest()
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            return true
        }
        guard let results = request.results else { return true }
        return results.contains { $0.identifier == "food" && $0.confidence >= minimumFoodConfidence }
    }

    private enum RenderMode {
        /// Aspect kept, centred, with letterbox bars: what the portion model trained on.
        case fit
        /// Aspect kept, centre-cropped: what the dish classifier trained on.
        case fill
    }

    /// Draws through UIKit so the photo's EXIF orientation is applied.
    private static func render(_ photo: UIImage, size: CGSize, mode: RenderMode) -> CGImage? {
        guard photo.size.width > 0, photo.size.height > 0 else { return nil }
        let widthRatio = size.width / photo.size.width
        let heightRatio = size.height / photo.size.height
        let scale = mode == .fit ? min(widthRatio, heightRatio) : max(widthRatio, heightRatio)
        let drawn = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
        let origin = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            letterboxColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.interpolationQuality = .high
            photo.draw(in: CGRect(origin: origin, size: drawn))
        }.cgImage
    }
}
