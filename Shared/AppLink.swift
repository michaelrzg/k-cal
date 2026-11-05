//
//  AppLink.swift
//  k-cal
//
//  The screens widgets can open.
//

import Foundation

enum AppLink: String, CaseIterable {
    case scan
    case snap
    case search
    case custom

    private static let scheme = "kcal"

    var url: URL {
        URL(string: "\(Self.scheme)://\(rawValue)")!
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, let link = url.host().flatMap(AppLink.init(rawValue:)) else { return nil }
        self = link
    }
}
