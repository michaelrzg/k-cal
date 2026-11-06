//
//  CalorieWidgets.swift
//  k-calWidgets
//

import SwiftUI
import WidgetKit

/// Today's calories with a progress bar, and its Lock Screen versions.
struct DailyCaloriesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyCalories", provider: DailyProvider()) { entry in
            DailyCaloriesView(snapshot: entry.snapshot)
                .containerBackground(WidgetColor.background, for: .widget)
                .widgetURL(AppLink.scan.url)
        }
        .configurationDisplayName("Daily Calories")
        .description("Today's calories against your goal.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

struct DailyCaloriesView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DailySnapshot

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: snapshot.calorieProgress) {
                Image(systemName: "flame")
            } currentValueLabel: {
                Text(max(snapshot.caloriesLeft, 0), format: .number.notation(.compactName))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryInline:
            Label("\(snapshot.remainingText) cal", systemImage: "flame")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.calories.formatted()) cal").font(.headline).widgetAccentable()
                Text(snapshot.remainingText).font(.caption)
                Gauge(value: snapshot.calorieProgress) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
            }
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Calories", systemImage: "flame.fill")
                .font(.caption)
                .foregroundStyle(WidgetColor.brand)
            Spacer()
            Text(snapshot.calories.formatted())
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("of \(snapshot.calorieGoal.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            ProgressBar(progress: snapshot.calorieProgress, color: WidgetColor.brand)
            Text(snapshot.remainingText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// The same numbers as a ring.
struct CalorieRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CalorieRing", provider: DailyProvider()) { entry in
            CalorieRingView(snapshot: entry.snapshot)
                .containerBackground(WidgetColor.background, for: .widget)
                .widgetURL(AppLink.scan.url)
        }
        .configurationDisplayName("Calorie Ring")
        .description("Calories left today, as a ring.")
        .supportedFamilies([.systemSmall])
    }
}

struct CalorieRingView: View {
    let snapshot: DailySnapshot

    var body: some View {
        ZStack {
            Circle().stroke(WidgetColor.brand.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: snapshot.calorieProgress)
                .stroke(WidgetColor.brand, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(abs(snapshot.caloriesLeft).formatted())
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(snapshot.caloriesLeft >= 0 ? "cal left" : "cal over")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
        }
        .padding(4)
    }
}
