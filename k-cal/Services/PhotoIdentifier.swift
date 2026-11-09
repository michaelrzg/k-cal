//
//  PhotoIdentifier.swift
//  k-cal
//
//  Decides what a photo shows, trying what's printed on it before estimating anything.
//

import UIKit

enum PhotoFinding: Equatable {
    /// A barcode that's in the database.
    case product(FoodProduct)
    case label(NutritionLabel)
    /// The likeliest products for the words on a package, best first.
    case package([FoodProduct])
    case meal
}

/// What the front of a package says.
struct FrontReading: Sendable {
    var printed: PrintedText
    /// The brand and product as Apple's model read them, where it's available.
    var seenName: String?
}

/// What two photos of a package, its front and its nutrition label, come to.
enum PackageFinding: Equatable {
    /// A barcode that's in the database.
    case product(FoodProduct)
    /// The panel's numbers, with a name for them from the front and the products it might be.
    case label(NutritionLabel, name: String, choices: [FoodProduct])
    /// No panel, but the front looks like one of these.
    case choices([FoodProduct])
    case unread
}

enum PhotoIdentifier {
    /// Enough for small print, without paying to read the full 48 MP.
    private static let longestSide: CGFloat = 3024
    private static let maximumQueries = 12
    private static let maximumChoices = 5

    static func identify(_ photo: UIImage, repository: FoodRepository = .shared) async -> PhotoFinding {
        guard let image = upright(photo) else { return .meal }
        var printed = await Task.detached(priority: .userInitiated) { PhotoReader.read(image) }.value
        // Only worth the wait if something's printed there, and a panel or barcode has already said more than this could.
        if printed.barcodes.isEmpty, !printed.texts.isEmpty, NutritionLabelParser.parse(printed.texts) == nil,
           let name = await PhotoFoodNamer.packageName(for: photo) {
            printed.texts += PackageMatcher.namedPieces(brand: name.brand, product: name.product)
        }
        return await finding(for: printed, repository: repository)
    }

    /// Which of the things in a photo to go with. A barcode names the exact product, so it outranks everything.
    /// A panel comes next because it can't be mistaken: three nutrients with amounts don't appear by chance.
    static func finding(for printed: PrintedText, repository: FoodRepository) async -> PhotoFinding {
        for code in printed.barcodes {
            if let product = try? await repository.product(barcode: code) { return .product(product) }
        }
        if let label = NutritionLabelParser.parse(printed.texts) { return .label(label) }
        let choices = await choices(for: printed.texts, repository: repository)
        return choices.isEmpty ? .meal : .package(choices)
    }

    // MARK: Two photos of a package

    /// Reads the front of a package. It's started as soon as that photo is taken, so it runs while you take the label.
    static func readFront(_ photo: UIImage) async -> FrontReading {
        guard let image = upright(photo) else { return FrontReading(printed: PrintedText(), seenName: nil) }
        async let seen = PhotoFoodNamer.packageName(for: photo)
        var printed = await Task.detached(priority: .userInitiated) { PhotoReader.read(image, findsPanel: false) }.value
        guard let name = await seen else { return FrontReading(printed: printed, seenName: nil) }
        printed.texts += PackageMatcher.namedPieces(brand: name.brand, product: name.product)
        let seenName = [name.brand, name.product]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return FrontReading(printed: printed, seenName: seenName.isEmpty ? nil : seenName)
    }

    /// Reads the side with the nutrition panel, trying hard for every number.
    static func readLabel(_ photo: UIImage) async -> PrintedText {
        guard let image = upright(photo) else { return PrintedText() }
        return await Task.detached(priority: .userInitiated) { PhotoReader.read(image) }.value
    }

    /// What the two photos add up to. A barcode on either side names the exact product. Otherwise the panel gives the
    /// numbers and the front gives the name, and failing a panel, the front alone is matched to products.
    static func package(front: FrontReading, label: PrintedText?, repository: FoodRepository = .shared) async -> PackageFinding {
        for code in (label?.barcodes ?? []) + front.printed.barcodes {
            if let product = try? await repository.product(barcode: code) { return .product(product) }
        }
        let panel = label.flatMap { NutritionLabelParser.parse($0.texts) } ?? NutritionLabelParser.parse(front.printed.texts)
        var choices = await choices(for: front.printed.texts, repository: repository)
        if let panel {
            let name = front.seenName ?? choices.first?.fullName ?? ""
            return .label(panel, name: name, choices: choices)
        }
        // The brand is often on the back too, if the front was hard to read.
        if choices.isEmpty, let label { choices = await self.choices(for: label.texts, repository: repository) }
        return choices.isEmpty ? .unread : .choices(choices)
    }

    /// The products in the database that the words in a photo best fit, best first.
    private static func choices(for texts: [LabelText], repository: FoodRepository) async -> [FoodProduct] {
        guard !texts.isEmpty else { return [] }
        let vocabulary = await repository.vocabulary()
        return await Task.detached(priority: .userInitiated) { () -> [FoodProduct] in
            guard let database = repository.bundled else { return [] }
            let words = PackageMatcher.searchWords(in: texts, vocabulary: vocabulary)
            let pool = PackageMatcher.queries(for: words).prefix(maximumQueries).flatMap { (try? database.search($0)) ?? [] }
            return PackageMatcher.choices(pool, texts: texts, vocabulary: vocabulary, limit: maximumChoices)
        }.value
    }

    /// With the photo's rotation applied, so that text reads the right way up.
    private static func upright(_ photo: UIImage) -> CGImage? {
        guard photo.size.width > 0, photo.size.height > 0 else { return nil }
        let scale = min(longestSide / max(photo.size.width, photo.size.height), 1)
        let size = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            photo.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}

extension FoodProduct {
    /// The name with its brand in front, unless the name already says it.
    var fullName: String {
        guard let brand = brand?.trimmingCharacters(in: .whitespacesAndNewlines), !brand.isEmpty,
              !name.localizedCaseInsensitiveContains(brand) else { return name }
        return "\(brand) \(name)"
    }

    /// A food read off a nutrition panel.
    init(label: NutritionLabel, name: String) {
        self.init(
            id: "label-\(UUID().uuidString)",
            name: name,
            serving: label.serving ?? label.amountGrams.map { "\(Int($0)) g" } ?? "1 serving",
            ingredients: nil,
            nutrition: label.nutrition,
            source: .custom,
            servingGrams: label.amountGrams
        )
    }
}
