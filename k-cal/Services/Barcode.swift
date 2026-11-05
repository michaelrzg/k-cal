//
//  Barcode.swift
//  k-cal
//
//  The same North American product can appear as UPC-A, EAN-13 or GTIN-14, which differ only in leading
//  zeros, and sources store whichever they were given.
//

import Foundation

enum Barcode {
    /// A form that compares equal across UPC-A, EAN-13 and GTIN-14: digits, no leading zeros.
    static func canonical(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard (8 ... 14).contains(digits.count) else { return nil }
        let stripped = String(digits.drop { $0 == "0" })
        return stripped.isEmpty ? nil : stripped
    }

    /// The spellings to search for, shortest first: UPC-A, EAN-13, GTIN-14.
    static func spellings(of raw: String) -> [String] {
        guard let canonical = canonical(raw) else { return [] }
        return [12, 13, 14].filter { $0 >= canonical.count }.map {
            String(repeating: "0", count: $0 - canonical.count) + canonical
        }
    }

    /// Expands an 8-digit UPC-E, found on small packages, to the 12-digit UPC-A it abbreviates.
    static func expandUPCE(_ code: String) -> String? {
        let digits = Array(code)
        guard digits.count == 8, digits.allSatisfy(\.isNumber) else { return nil }
        let (system, check) = (digits[0], digits[7])
        let body = Array(digits[1 ..< 7])
        let middle: [Character]
        switch body[5] {
        case "0", "1", "2":
            middle = [body[0], body[1], body[5], "0", "0", "0", "0", body[2], body[3], body[4]]
        case "3":
            middle = [body[0], body[1], body[2], "0", "0", "0", "0", "0", body[3], body[4]]
        case "4":
            middle = [body[0], body[1], body[2], body[3], "0", "0", "0", "0", "0", body[4]]
        default:
            middle = [body[0], body[1], body[2], body[3], body[4], "0", "0", "0", "0", body[5]]
        }
        return String([system] + middle + [check])
    }
}
