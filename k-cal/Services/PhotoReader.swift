//
//  PhotoReader.swift
//  k-cal
//
//  Reads what's printed in a photo: barcodes and text. It runs before the meal models, because anything printed on a
//  package beats an estimate of what's inside it.
//

import CoreGraphics
import Foundation
import ImageIO
import Vision

/// What's printed in a photo.
struct PrintedText: Sendable {
    var barcodes: [String] = []
    var texts: [LabelText] = []
}

enum PhotoReader {
    /// Below this, Vision's reading of a piece of text is usually a logo or a pattern.
    private static let minimumTextConfidence: Float = 0.3
    private static let minimumPlausibleCalories = 25.0
    private static let closeUpSide: CGFloat = 2600
    private static let maximumZoom: CGFloat = 4

    /// - Parameter findsPanel: whether to keep trying for a nutrition panel when the first reading isn't one. Off for
    ///   the front of a package, which has none, so it's read in one pass.
    static func read(_ image: CGImage, findsPanel: Bool = true) -> PrintedText {
        var printed = PrintedText(barcodes: barcodes(in: image))
        printed.texts = recognise(image, orientation: .up)
        var label = NutritionLabelParser.parse(printed.texts)
        guard findsPanel, label?.isComplete != true else { return printed }

        // A panel is often photographed sideways to fill the frame, and part of one can still read as a panel upright.
        for orientation in [CGImagePropertyOrientation.right, .left] {
            let turned = recognise(image, orientation: orientation)
            let reading = NutritionLabelParser.parse(turned)
            if quality(of: reading) > quality(of: label) {
                printed.texts = turned
                label = reading
            }
        }
        // Small print in a big photo is often missed on the first pass, but not when it fills the frame. A sideways
        // panel is left alone here, because the region found is in turned coordinates.
        if let current = label, !current.isComplete, let region = NutritionLabelParser.panelRegion(in: printed.texts),
           let closer = enlarged(region, of: image) {
            let again = recognise(closer, orientation: .up)
            let reading = NutritionLabelParser.parse(again)
            if quality(of: reading) > quality(of: current) { printed.texts = again }
        }
        return printed
    }

    /// How much of a panel a reading got, for choosing between attempts.
    private static func quality(of label: NutritionLabel?) -> Int {
        guard let label else { return 0 }
        // Tiny numbers always "add up", and a misread photo is full of them.
        let plausible = label.addsUp && label.nutrition.calories >= minimumPlausibleCalories
        return 1 + (3 - label.unread.count) + (plausible ? 4 : 0)
    }

    /// Part of an image at a size where small print is easy to read.
    private static func enlarged(_ region: CGRect, of image: CGImage) -> CGImage? {
        let crop = CGRect(
            x: region.minX * CGFloat(image.width), y: region.minY * CGFloat(image.height),
            width: region.width * CGFloat(image.width), height: region.height * CGFloat(image.height)
        ).integral
        guard crop.width > 0, crop.height > 0, let part = image.cropping(to: crop) else { return nil }
        let scale = min(max(closeUpSide / max(crop.width, crop.height), 1), maximumZoom)
        let width = Int(crop.width * scale), height = Int(crop.height * scale)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(part, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func barcodes(in image: CGImage) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.ean13, .ean8, .upce, .code128, .itf14]
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else { return [] }
        return (request.results ?? []).compactMap { barcode in
            guard let payload = barcode.payloadStringValue else { return nil }
            return barcode.symbology == .upce ? Barcode.expandUPCE(payload) ?? payload : payload
        }
    }

    private static func recognise(_ image: CGImage, orientation: CGImagePropertyOrientation) -> [LabelText] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Correction turns "0g" into words and brand names into dictionary ones.
        request.usesLanguageCorrection = false
        guard (try? VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])) != nil else { return [] }
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= minimumTextConfidence else { return nil }
            let box = observation.boundingBox
            return LabelText(text: candidate.string, box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
        }
    }
}
