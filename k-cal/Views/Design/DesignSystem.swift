//
//  DesignSystem.swift
//  k-cal
//
//  The shared look of the app: system materials and dynamic type, the brand and macro colours, and rounded
//  numerals for anything worth reading at a glance.
//

import SwiftUI

enum Theme {
    static let brand = Color("k-cal")
    /// Text on a filled brand button: white fails contrast on the lighter clay used in dark mode.
    static let onBrand = Color("OnAccent")
    static let protein = Color("Protein")
    static let carbohydrate = Color("Carbohydrate")
    static let fat = Color("Fat")
    static let background = Color("Background")
    static let card = Color("Foreground")
    static let cornerRadius: CGFloat = 20
}

extension View {
    /// Swaps a list's cool system greys for the app's warm background. Rows take `Theme.card` by section.
    func themedList() -> some View {
        // Past the safe area, or the window behind it shows through as the keyboard moves.
        scrollContentBackground(.hidden).background(Theme.background.ignoresSafeArea())
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension Font {
    static func numeral(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// The ring on the summary card. Goes red only once the goal is passed.
struct CalorieRing: View {
    let calories: Int
    let goal: Int

    private var progress: Double {
        DailySnapshot.progress(calories, of: goal)
    }

    private var left: Int {
        goal - calories
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.brand.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(left < 0 ? Color.red : Theme.brand, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
            VStack(spacing: 0) {
                Text(abs(left).formatted())
                    .font(.numeral(30))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text(left < 0 ? "cal over" : "cal left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
        }
        .frame(width: 128, height: 128)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(left < 0 ? "\(-left) calories over goal" : "\(left) calories left")
    }
}

struct MacroMeter: View {
    let name: String
    let value: Int
    let goal: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(value) / \(goal) g")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * DailySnapshot.progress(value, of: goal))
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(value) of \(goal) grams")
    }
}

/// The day at a glance, on Today and in the Diary.
struct DaySummaryCard: View {
    let foods: [Food]
    let goals: DayGoals
    /// Says which goals apply, when they follow your training.
    var caption: String?

    private func total(_ amount: (Food) -> Int) -> Int {
        foods.reduce(0) { $0 + amount($1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                CalorieRing(calories: total(\.calories), goal: goals.calories)
                VStack(spacing: 10) {
                    MacroMeter(name: "Protein", value: total(\.protein), goal: goals.protein, color: Theme.protein)
                    MacroMeter(name: "Carbs", value: total(\.carbohydrates), goal: goals.carbohydrates, color: Theme.carbohydrate)
                    MacroMeter(name: "Fat", value: total(\.fat), goal: goals.fat, color: Theme.fat)
                }
            }
            if let caption {
                Label(caption, systemImage: "dumbbell.fill").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

/// A tile for one way of adding food.
struct ActionTile: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Theme.brand)
                    .frame(height: 28)
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A rounded placeholder or photo for a food in a list.
struct FoodThumbnail: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.tertiarySystemFill)
                }
            } else {
                Color(.tertiarySystemFill)
                    .overlay(Image(systemName: "fork.knife").font(.footnote).foregroundStyle(.secondary))
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A banner sized for a list row, with nothing behind it.
struct InlineAd: View {
    let unitID: String

    var body: some View {
        AdBannerView(adUnitID: unitID)
            .frame(width: 320, height: 50)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
    }
}
