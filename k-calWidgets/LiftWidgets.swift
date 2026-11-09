//
//  LiftWidgets.swift
//  k-calWidgets
//

import SwiftUI
import WidgetKit

struct LiftEntry: TimelineEntry {
    let date: Date
    let snapshot: LiftSnapshot?
}

/// Only midnight needs a new entry: that's when a rest day becomes a training day.
struct LiftProvider: TimelineProvider {
    private static let sample = LiftSnapshot(
        week: 3, totalWeeks: 13, phase: "Foundation", dayName: "Upper Heavy", focus: "Bench and row", minutes: 60,
        lines: [.init(name: "Barbell Bench Press", detail: "4 x 9 at 165 lb"), .init(name: "Barbell Row", detail: "4 x 9 at 130 lb"), .init(name: "Seated Dumbbell Press", detail: "4 x 12 at 65 lb")],
        weekdays: [1, 2, 3, 4, 5, 6, 7], lastTrained: nil
    )

    func placeholder(in _: Context) -> LiftEntry {
        LiftEntry(date: Date(), snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (LiftEntry) -> Void) {
        completion(LiftEntry(date: Date(), snapshot: context.isPreview ? Self.sample : LiftSnapshot.load()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<LiftEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let snapshot = LiftSnapshot.load()
        completion(Timeline(entries: [LiftEntry(date: now, snapshot: snapshot), LiftEntry(date: midnight, snapshot: snapshot)], policy: .after(midnight)))
    }
}

struct NextWorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextWorkout", provider: LiftProvider()) { entry in
            NextWorkoutView(entry: entry)
                .containerBackground(WidgetColor.background, for: .widget)
                .widgetURL(AppLink.lifts.url)
        }
        .configurationDisplayName("Next Workout")
        .description("Your next session and where you are in your program.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct NextWorkoutView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LiftEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryCircular:
                Gauge(value: snapshot.progress) {
                    Image(systemName: "dumbbell.fill")
                } currentValueLabel: {
                    Text("\(snapshot.week)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.dayName).font(.headline).widgetAccentable().lineLimit(1)
                    Text(snapshot.lines.first?.detail ?? snapshot.focus).font(.caption).lineLimit(1)
                    Text("Week \(snapshot.week) of \(snapshot.totalWeeks)").font(.caption2).foregroundStyle(.secondary)
                }
            case .systemMedium:
                HStack(spacing: 16) {
                    summary(snapshot).frame(maxWidth: 136, alignment: .leading)
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(snapshot.lines.prefix(3).enumerated()), id: \.offset) { _, line in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(line.name).font(.caption.weight(.medium)).lineLimit(1)
                                Text(line.detail).font(.caption2).monospacedDigit().foregroundStyle(WidgetColor.brand).lineLimit(1)
                            }
                        }
                    }
                }
            default:
                summary(snapshot)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "dumbbell.fill").font(.title2).foregroundStyle(WidgetColor.brand)
                if family != .accessoryCircular {
                    Text("Set up Lifts").font(.caption.weight(.medium))
                }
            }
        }
    }

    private func summary(_ snapshot: LiftSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(snapshot.headline(on: entry.date), systemImage: "dumbbell.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WidgetColor.brand)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Text(snapshot.dayName)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text("\(snapshot.minutes) min").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 2)
            ProgressBar(progress: snapshot.progress, color: WidgetColor.brand, height: 7)
            Text("Week \(snapshot.week) of \(snapshot.totalWeeks), \(snapshot.phase)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
