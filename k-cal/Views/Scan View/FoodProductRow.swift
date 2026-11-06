//
//  FoodProductRow.swift
//  k-cal
//
//  One food in a list of results. The whole row adds it.
//

import SwiftUI

struct FoodProductRow: View {
    let product: FoodProduct
    let onAdd: () -> Void

    private var detail: String {
        [product.brand ?? (product.source == .custom ? "" : product.source.rawValue), product.serving]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func rounded(_ value: Double) -> Int {
        Int(value.rounded())
    }

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 12) {
                FoodThumbnail(url: product.imageURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name).lineLimit(2)
                    if !detail.isEmpty {
                        Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(rounded(product.nutrition.calories).formatted())
                        .font(.numeral(17, weight: .semibold))
                        .monospacedDigit()
                    Text("cal").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(product.name)")
    }
}
