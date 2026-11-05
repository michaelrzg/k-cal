//
//  MacroWidgets.swift
//  k-calWidgets
//

import SwiftUI
import WidgetKit

/// Protein, carbs and fat against their goals.
struct DailyMacrosWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyMacros", provider: DailyProvider()) { entry in
            DailyMacrosView(snapshot: entry.snapshot)
                .containerBackground(.background, for: .widget)
                .widgetURL(AppLink.scan.url)
        }
        .configurationDisplayName("Daily Macros")
        .description("Protein, carbs and fat against your goals.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct DailyMacrosView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DailySnapshot

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreen
        case .systemSmall:
            bars
        default:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today").font(.caption).foregroundStyle(WidgetColor.brand)
                    Text(snapshot.calories.formatted())
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("cal, \(snapshot.remainingText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 100, alignment: .leading)
                bars
            }
        }
    }

    private var bars: some View {
        VStack(spacing: 8) {
            MacroBar(name: "Protein", value: snapshot.protein, goal: snapshot.proteinGoal, color: WidgetColor.protein)
            MacroBar(name: "Carbs", value: snapshot.carbohydrates, goal: snapshot.carbohydrateGoal, color: WidgetColor.carbohydrate)
            MacroBar(name: "Fat", value: snapshot.fat, goal: snapshot.fatGoal, color: WidgetColor.fat)
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 1) {
            lockRow("P", snapshot.protein, snapshot.proteinGoal)
            lockRow("C", snapshot.carbohydrates, snapshot.carbohydrateGoal)
            lockRow("F", snapshot.fat, snapshot.fatGoal)
        }
    }

    private func lockRow(_ letter: String, _ value: Int, _ goal: Int) -> some View {
        HStack(spacing: 4) {
            Text(letter).font(.caption2).bold().frame(width: 10)
            Gauge(value: DailySnapshot.progress(value, of: goal)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
            Text("\(value)g").font(.caption2).monospacedDigit().frame(width: 34, alignment: .trailing)
        }
    }
}
