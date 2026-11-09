//
//  PhotoFoodNamer.swift
//  k-cal
//
//  Reads what a photo shows using Apple's on-device model, where there is one: a name for a meal, or the brand on a package.
//
//  It names only, on purpose. On 1,000 phone photos it named foods well, but its own calories were out by 62%, against
//  29% for the plate model, and adding them to that model changed the result by under a point.
//

import Foundation
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

enum PhotoFoodNamer {
    private static let maximumNames = 3
    private static let timeout: Duration = .seconds(15)
    private static let imageSide: CGFloat = 768

    /// A meal title from the model's foods: "Chicken, greens, sauce".
    static func title(from names: [String]) -> String? {
        var seen = Set<String>()
        let cleaned = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(maximumNames)
            .map { $0.lowercased() }
        guard let first = cleaned.first else { return nil }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + cleaned.dropFirst()).joined(separator: ", ")
    }

    /// A suggested name, or nil if this phone can't, or the model has nothing useful to say.
    static func suggestion(for photo: UIImage) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 27, *), case .available = SystemLanguageModel.default.availability,
              let image = scaled(photo) else { return nil }
        return await firstResult { await names(in: image).flatMap(title(from:)) }
        #else
        return nil
        #endif
    }

    /// The brand and product printed on a package. It reads logos, which OCR can't: on 330 packages the brand was
    /// right 81% of the time, and adding this took finding the right product from 54% to 71%.
    static func packageName(for photo: UIImage) async -> (brand: String, product: String)? {
        #if canImport(FoundationModels)
        guard #available(iOS 27, *), case .available = SystemLanguageModel.default.availability,
              let image = scaled(photo) else { return nil }
        return await firstResult { await package(in: image) }
        #else
        return nil
        #endif
    }

    /// What `work` gives, or nil if it takes too long.
    private static func firstResult<Result: Sendable>(_ work: @escaping @Sendable () async -> Result?) async -> Result? {
        await withTaskGroup(of: Result?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func scaled(_ photo: UIImage) -> CGImage? {
        let longest = max(photo.size.width, photo.size.height)
        guard longest > 0 else { return nil }
        let scale = min(imageSide / longest, 1)
        let size = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            photo.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    #if canImport(FoundationModels)
    @available(iOS 27, *)
    @Generable(description: "The foods visible in a meal photo")
    struct SeenPlate {
        @Guide(description: "Each separate food on the plate, as a short common name, largest portion first")
        var foods: [String]
    }

    @available(iOS 27, *)
    @Generable(description: "A packaged food in a photo")
    struct SeenPackage {
        @Guide(description: "The brand printed on the package, such as Lay's or Coca-Cola, or an empty string if it can't be seen")
        var brand: String
        @Guide(description: "The product name and flavor printed on the package, such as Classic Potato Chips")
        var product: String
    }

    @available(iOS 27, *)
    private static func package(in image: CGImage) async -> (brand: String, product: String)? {
        let session = LanguageModelSession(instructions: "You read food packaging in photos for a calorie tracker. Report only what is printed on the package.")
        let response = try? await session.respond(generating: SeenPackage.self) {
            "What is this product?"
            Attachment(image)
        }
        return response.map { ($0.content.brand, $0.content.product) }
    }

    @available(iOS 27, *)
    private static func names(in image: CGImage) async -> [String]? {
        let session = LanguageModelSession(instructions: "You identify food in photos for a calorie tracking app. Name only what you can see. Don't guess at hidden ingredients.")
        let response = try? await session.respond(generating: SeenPlate.self) {
            "List the foods in this photo."
            Attachment(image)
        }
        return response?.content.foods
    }
    #endif
}
