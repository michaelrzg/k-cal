//
//  NutritionLabel.swift
//  k-cal
//
//  Turns the text on a nutrition panel into numbers. It works on text and positions alone, so it needs no camera.
//

import CoreGraphics
import Foundation

/// A piece of recognised text. Boxes run from 0 to 1 with y going down, in the upright photo.
struct LabelText: Equatable, Sendable {
    var text: String
    var box: CGRect
}

/// What a panel says.
struct NutritionLabel: Equatable, Sendable {
    /// Amounts for one serving where the panel gives them, otherwise for `amountGrams`.
    var nutrition: Nutrition
    /// How the serving is described, such as "1 oz (28g/About 15 chips)".
    var serving: String?
    /// The weight the amounts are for, where the panel says.
    var amountGrams: Double?
    var servingsPerContainer: Double?
    /// Macros the panel seemed to have but that couldn't be read. They stay at zero until someone fills them in.
    var unread: [String] = []

    /// Nothing is missing and the numbers agree, so the photo needn't be read again.
    var isComplete: Bool { unread.isEmpty && addsUp }

    /// True when the energy from the macros agrees with the stated calories, which a misread number rarely does.
    var addsUp: Bool {
        let fromMacros = nutrition.protein * 4 + nutrition.carbohydrates * 4 + nutrition.fat * 9
        // Fiber and sugar alcohols count for less than 4, so carbs can run high. Rounding matters on small servings.
        return abs(fromMacros - nutrition.calories) <= max(nutrition.calories * 0.25, 15)
    }
}

enum NutritionLabelParser {
    /// Fewer than this and it isn't a panel, just a package that mentions a nutrient.
    private static let minimumNutrients = 3

    private enum Nutrient: CaseIterable {
        case calories, fat, carbohydrates, protein, sodium, salt, sugars, fiber

        /// Lowercased names, longest first where one contains another, in the languages panels use most.
        var names: [String] {
            switch self {
            case .calories: ["calories", "calorie", "energy", "energie", "énergie", "energía", "energia", "brennwert"]
            case .fat: ["total fat", "total fats", "fat", "fats", "lipides", "matières grasses", "matieres grasses", "grasas", "fett", "grassi"]
            case .carbohydrates: ["total carbohydrates", "total carbohydrate", "total carbs", "total carb", "carbohydrates", "carbohydrate", "carbs", "glucides", "hidratos de carbono", "kohlenhydrate", "carboidrati"]
            case .protein: ["proteins", "protein", "protéines", "proteines", "proteínas", "proteinas", "eiweiß", "eiweiss", "proteine"]
            case .sodium: ["sodium", "sodio", "natrium"]
            case .salt: ["salt", "sel", "salz", "sale"]
            case .sugars: ["total sugars", "total sugar", "sugars", "sugar", "sucres", "azúcares", "azucares", "zucker", "zuccheri"]
            case .fiber: ["dietary fiber", "dietary fibre", "fiber", "fibre", "fibres", "fibra", "ballaststoffe"]
            }
        }
    }

    /// Words just before a nutrient's name that make it a different figure, such as saturated fat.
    private static let qualifiers = [
        "saturated", "unsaturated", "sat", "sat.", "trans", "polyunsaturated", "monounsaturated", "poly", "mono", "added", "includes",
        "from", "soluble", "insoluble", "alcohol", "other", "of which", "saturates", "saturés", "saturi", "saturadas", "gesättigte", "dont",
        "daily", "per"
    ]
    /// Nutrient names followed by these aren't figures at all.
    private static let trailers = ["alcohol", "per ", "a day", "diet", "free", "from", "cal "]
    /// Words worth correcting when OCR gets one letter wrong, as in "Profein". They're long enough not to hit other words.
    private static let correctable = ["protein", "calories", "carbohydrate", "carbohydrates", "sodium", "sugars", "dietary"]

    /// One name found in the text, with what follows it in the same piece.
    private struct Hit {
        var nutrient: Nutrient
        var piece: LabelText
        var rest: String
    }

    static func parse(_ texts: [LabelText]) -> NutritionLabel? {
        let columnX = servingColumn(texts)
        var per100Column = false
        if case .per100 = columnX { per100Column = true }
        var found: [Nutrient: Double] = [:]
        var calorieOptions: [Double] = []

        for hit in hits(in: texts) where hit.nutrient == .calories || found[hit.nutrient] == nil {
            var amounts = amounts(in: hit.rest, nutrient: hit.nutrient, box: hit.piece.box)
            if amounts.isEmpty { amounts = neighbours(of: hit.piece, in: texts).flatMap { self.amounts(in: $0.text, nutrient: hit.nutrient, box: $0.box) } }
            if hit.nutrient == .calories, amounts.isEmpty { amounts = below(hit.piece, in: texts).flatMap { self.amounts(in: $0.text, nutrient: .calories, box: $0.box) } }
            guard let amount = pick(amounts, column: columnX, nutrient: hit.nutrient) else { continue }
            if hit.nutrient == .calories { calorieOptions.append(amount) } else { found[hit.nutrient] = amount }
        }

        let fromMacros = found[.protein].flatMap { protein in
            found[.carbohydrates].flatMap { carbs in found[.fat].map { protein * 4 + carbs * 4 + $0 * 9 } }
        }
        let calories: Double? = if let fromMacros, !calorieOptions.isEmpty {
            calorieOptions.min { abs($0 - fromMacros) < abs($1 - fromMacros) }
        } else {
            calorieOptions.first ?? fromMacros
        }
        guard let calories, found.count + (calorieOptions.isEmpty ? 0 : 1) >= minimumNutrients else { return nil }

        let serving = servingText(texts)
        var label = NutritionLabel(
            nutrition: Nutrition(
                calories: calories, protein: found[.protein] ?? 0, carbohydrates: found[.carbohydrates] ?? 0, fat: found[.fat] ?? 0,
                sodiumMilligrams: found[.sodium] ?? found[.salt].map { $0 * 400 } ?? 0, sugars: found[.sugars] ?? 0, fiber: found[.fiber] ?? 0
            ),
            serving: serving,
            amountGrams: per100Column ? 100 : serving.flatMap(grams(in:)),
            servingsPerContainer: servingsPerContainer(texts),
            unread: [(Nutrient.protein, "Protein"), (.carbohydrates, "Carbs"), (.fat, "Fat")].compactMap { found[$0.0] == nil ? $0.1 : nil }
        )
        if !label.addsUp { repair(&label) }
        return label
    }

    /// Where a panel is in the photo, for reading it again up close. Nil if there's no sign of one.
    static func panelRegion(in texts: [LabelText]) -> CGRect? {
        let boxes = hits(in: texts).map(\.piece.box)
        guard boxes.count >= minimumNutrients, var region = boxes.first else { return nil }
        for box in boxes.dropFirst() { region = region.union(box) }
        // Amounts sit to the right of their names, so it reaches out further on that side.
        let wider = region.insetBy(dx: -region.width * 0.25, dy: -region.height * 0.12)
        let reached = CGRect(x: wider.minX, y: wider.minY, width: wider.width + region.width * 0.75, height: wider.height)
        return reached.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    // MARK: Finding names

    private static let searches: [(nutrient: Nutrient, name: String)] = Nutrient.allCases
        .flatMap { nutrient in nutrient.names.map { (nutrient, $0) } }
        .sorted { $0.name.count > $1.name.count }

    private static func hits(in texts: [LabelText]) -> [Hit] {
        // Reading order, so the headline figure comes before any repeat in a footnote.
        let ordered = texts.sorted { abs($0.box.midY - $1.box.midY) < 0.004 ? $0.box.minX < $1.box.minX : $0.box.midY < $1.box.midY }
        var results: [Hit] = []
        for piece in ordered {
            var line = corrected(piece.text.lowercased())
            // Longest names first, blanking each one out so "total fat" isn't found again as "fat".
            var found: [(offset: Int, end: Int, nutrient: Nutrient)] = []
            for (nutrient, name) in searches {
                while let range = line.range(of: name) {
                    let start = line.distance(from: line.startIndex, to: range.lowerBound)
                    let end = line.distance(from: line.startIndex, to: range.upperBound)
                    let before = line[..<range.lowerBound]
                    let after = line[range.upperBound...]
                    let bounded = !(before.last?.isLetter ?? false) && !(after.first?.isLetter ?? false)
                    let word = before.split(whereSeparator: { !$0.isLetter && $0 != "." }).last.map(String.init) ?? ""
                    let tail = after.trimmingCharacters(in: .whitespaces)
                    let wanted = bounded && !qualifiers.contains(word) && !trailers.contains(where: tail.hasPrefix)
                    if wanted { found.append((start, end, nutrient)) }
                    line.replaceSubrange(range, with: String(repeating: "~", count: name.count))
                }
            }
            let sorted = found.sorted { $0.offset < $1.offset }
            let characters = Array(piece.text)
            for (index, item) in sorted.enumerated() {
                let stop = index + 1 < sorted.count ? sorted[index + 1].offset : characters.count
                guard item.end <= stop, stop <= characters.count else { continue }
                results.append(Hit(nutrient: item.nutrient, piece: piece, rest: String(characters[item.end ..< stop])))
            }
        }
        return results
    }

    /// Same length in characters as the input, so offsets into it hold for the original text.
    private static func corrected(_ line: String) -> String {
        line.split(separator: " ", omittingEmptySubsequences: false).map { word in
            guard word.count >= 6, !correctable.contains(String(word)) else { return String(word) }
            let letters = Array(word)
            let match = correctable.first { name in
                name.count == letters.count && zip(name, letters).filter { $0 != $1 }.count == 1
            }
            return match ?? String(word)
        }.joined(separator: " ")
    }

    /// Pieces level with this one and to its right, nearest first.
    private static func neighbours(of piece: LabelText, in texts: [LabelText]) -> [LabelText] {
        texts.filter { other in
            guard other != piece, other.box.minX >= piece.box.midX else { return false }
            let overlap = min(piece.box.maxY, other.box.maxY) - max(piece.box.minY, other.box.minY)
            return overlap > min(piece.box.height, other.box.height) * 0.5
        }.sorted { $0.box.minX < $1.box.minX }
    }

    /// "Calories" on one line with a large "140" under it.
    private static func below(_ piece: LabelText, in texts: [LabelText]) -> [LabelText] {
        texts.filter { other in
            other != piece && other.box.minY >= piece.box.midY && other.box.minY - piece.box.maxY < piece.box.height * 1.5
        }.sorted { $0.box.minY < $1.box.minY }.prefix(2).map { $0 }
    }

    // MARK: Columns

    private enum ServingColumn {
        case only
        case at(CGFloat)
        case per100(CGFloat)
    }

    /// Panels with two columns give per 100 g and per serving. A serving is what gets logged, so it wins.
    private static func servingColumn(_ texts: [LabelText]) -> ServingColumn {
        var per100: CGFloat?
        var perServing: CGFloat?
        for piece in texts {
            let text = piece.text.lowercased()
            if text.range(of: #"(per|pour|por|pro|/|je|par)\s*100\s*(g|ml)|^100\s*(g|ml)$"#, options: .regularExpression) != nil {
                per100 = piece.box.midX
            } else if text.contains("per serving") && !text.contains("amount") || text.contains("per portion") || text.contains("par portion") || text.contains("por porción") {
                perServing = piece.box.midX
            }
        }
        if let perServing, per100 != nil { return .at(perServing) }
        if let per100 { return .per100(per100) }
        return .only
    }

    private static func pick(_ amounts: [Amount], column: ServingColumn, nutrient: Nutrient) -> Double? {
        var options = amounts
        if nutrient == .calories {
            let kcal = options.filter { $0.unit == "kcal" }
            let plain = options.filter { $0.unit == nil }
            let kilojoules = options.filter { $0.unit == "kj" }.map { Amount(value: $0.value / 4.184, unit: "kcal", x: $0.x) }
            options = !kcal.isEmpty ? kcal : !plain.isEmpty ? plain : kilojoules
        }
        switch column {
        case .only: return options.first?.value
        case let .at(x), let .per100(x):
            return (options.count > 1 ? options.min { abs($0.x - x) < abs($1.x - x) } : options.first)?.value
        }
    }

    // MARK: Amounts

    private struct Amount {
        var value: Double
        var unit: String?
        var x: CGFloat
    }

    private static let amountPattern = try! NSRegularExpression(
        pattern: #"(?<![\d.,])(\d{1,4}(?:[.,]\d{1,2})?)\s*(kcal|cal|kj|mg|g)?(?![a-z\d])\s*(%?)"#, options: .caseInsensitive
    )

    /// Amounts in some text, mg and g put right for the nutrient, skipping any % Daily Value.
    private static func amounts(in raw: String, nutrient: Nutrient, box: CGRect) -> [Amount] {
        let text = cleaned(raw)
        var results: [Amount] = []
        for match in amountPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let numberRange = Range(match.range(at: 1), in: text) else { continue }
            let digits = String(text[numberRange]).replacingOccurrences(of: ",", with: ".")
            guard var value = Double(digits) else { continue }
            var unit = Range(match.range(at: 2), in: text).map { String(text[$0]).lowercased() }
            if unit == "cal" { unit = "kcal" }
            if Range(match.range(at: 3), in: text).map({ !text[$0].isEmpty }) ?? false { continue }
            let middle = CGFloat(match.range.location) + CGFloat(match.range.length) / 2
            let x = box.minX + box.width * middle / CGFloat(max(text.utf16.count, 1))
            switch nutrient {
            case .calories:
                if unit == "g" || unit == "mg" { continue }
            case .sodium:
                if unit == "kcal" || unit == "kj" { continue }
                if unit == "g" { value *= 1000 }
                unit = "mg"
            default:
                if unit == "kcal" || unit == "kj" { continue }
                if unit == "mg" { value /= 1000 }
                // A "g" read as 9: "Protein 129" is 12 g.
                if unit == nil, digits.count > 1, digits.hasSuffix("9"), !digits.contains(".") { value = (value / 10).rounded(.down) }
                unit = "g"
            }
            results.append(Amount(value: value, unit: unit, x: x))
        }
        return results
    }

    /// Fixes what OCR does beside a unit: "0g" comes back as "Og", "1g" as "lg", "8g" as "Bg", "5g" as "Sg", and g as q.
    private static func cleaned(_ text: String) -> String {
        var line = text.replacing(#/(\d)\s?gg\b/#) { "\($0.output.1)g" }
        line = line.replacing(#/\b[Oo]\s?(g|mg)\b/#) { "0\($0.output.1)" }
        line = line.replacing(#/\b[lI|]\s?(g|mg)\b/#) { "1\($0.output.1)" }
        line = line.replacing(#/\bB\s?(g|mg)\b/#) { "8\($0.output.1)" }
        line = line.replacing(#/\bS\s?(g|mg)\b/#) { "5\($0.output.1)" }
        line = line.replacing(#/\b(\d+(?:[.,]\d+)?)\s?[qQ]\b/#) { "\($0.output.1)g" }
        line = line.replacing(#/\b(\d)[oO](\d*)\s?(g|mg)\b/#) { "\($0.output.1)0\($0.output.2)\($0.output.3)" }
        line = line.replacing(#/(?i)\bless than\s*/#) { _ in "" }
        return line.replacingOccurrences(of: "<", with: "")
    }

    /// When the numbers disagree, OCR has usually lost a decimal point.
    private static func repair(_ label: inout NutritionLabel) {
        for keyPath in [\Nutrition.fat, \Nutrition.protein, \Nutrition.carbohydrates] {
            var attempt = label
            attempt.nutrition[keyPath: keyPath] /= 10
            if attempt.addsUp {
                label = attempt
                return
            }
        }
    }

    // MARK: Servings

    private static func servingText(_ texts: [LabelText]) -> String? {
        let ordered = texts.sorted { $0.box.midY < $1.box.midY }
        for (index, piece) in ordered.enumerated() {
            let text = piece.text
            guard let range = text.range(of: #"(?i)(serving size|serv\.? size|portion size)\b:?"#, options: .regularExpression) else { continue }
            var rest = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if rest.isEmpty {
                let level = neighbours(of: piece, in: texts).first?.text
                rest = level ?? (index + 1 < ordered.count ? ordered[index + 1].text : "")
            }
            if rest.contains(where: \.isNumber) || rest.lowercased().hasPrefix("about") { return rest }
        }
        return nil
    }

    /// "1 oz (28g/About 15 chips)" weighs 28.
    static func grams(in serving: String) -> Double? {
        let text = serving.replacing(#/(\d)\s?[qQ]\b/#) { "\($0.output.1)g" }
        if let match = text.firstMatch(of: #/(?i)(\d+(?:[.,]\d+)?)\s?(g|gram|grams|ml)\b/#) {
            return Double(match.output.1.replacingOccurrences(of: ",", with: "."))
        }
        if let ounces = text.firstMatch(of: #/(?i)(\d+(?:\.\d+)?)\s?oz\b/#), let value = Double(ounces.output.1) { return value * 28.35 }
        return nil
    }

    private static func servingsPerContainer(_ texts: [LabelText]) -> Double? {
        for piece in texts {
            let text = piece.text.lowercased()
            guard text.range(of: #"servings?\s*per|per (container|package|pack)|\d\s*servings"#, options: .regularExpression) != nil else { continue }
            if let match = text.firstMatch(of: #/(\d+(?:\.\d+)?)/#), let value = Double(match.output.1), value < 500 { return value }
        }
        return nil
    }
}
