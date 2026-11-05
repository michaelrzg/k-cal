//
//  FoodProductRow.swift
//  k-cal
//
//  One food in a list of results.
//

import SwiftUI

struct FoodProductRow: View {
    let product: FoodProduct
    let onAdd: () -> Void

    private var detail: String {
        [product.brand ?? product.source.rawValue, product.serving]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(product.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Spacer()
                    Text("\(rounded(product.nutrition.calories)) cal")
                        .font(.subheadline)
                        .foregroundStyle(Color("k-cal"))
                }
                HStack {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(rounded(product.nutrition.protein))")
                    Text("p").foregroundStyle(Color("Protein"))
                    Text("|")
                    Text("\(rounded(product.nutrition.carbohydrates))")
                    Text("c").foregroundStyle(Color("Carbohydrate"))
                    Text("|")
                    Text("\(rounded(product.nutrition.fat))")
                    Text("f").foregroundStyle(Color("Fat"))
                }
                .font(.subheadline)
            }
            Button(action: onAdd) {
                Image(systemName: "plus.circle").scaleEffect(1.3)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Add \(product.name)")
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = product.imageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(.systemGray5).overlay(ProgressView())
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
                .overlay(Image(systemName: "fork.knife").foregroundStyle(.secondary))
        }
    }

    private func rounded(_ value: Double) -> Int {
        Int(value.rounded())
    }
}
