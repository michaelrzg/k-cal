//
//  WidgetSupport.swift
//  k-calWidgets
//
//  What the widgets have in common: their timeline, colours and shared pieces of view.
//

import SwiftUI
import WidgetKit

struct DailyEntry: TimelineEntry {
    let date: Date
    let snapshot: DailySnapshot
}

/// Reads the app's summary. The app reloads widgets whenever it changes, so the only change a widget has to
/// expect by itself is midnight, when the day's totals go back to zero.
struct DailyProvider: TimelineProvider {
    private static let sample: DailySnapshot = {
        var sample = DailySnapshot(day: Date())
        sample.calories = 1240
        sample.protein = 92
        sample.carbohydrates = 130
        sample.fat = 41
        return sample
    }()

    func placeholder(in _: Context) -> DailyEntry {
        DailyEntry(date: Date(), snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        let now = Date()
        completion(DailyEntry(date: now, snapshot: context.isPreview ? Self.sample : DailySnapshot.load(for: now)))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let entries = [
            DailyEntry(date: now, snapshot: DailySnapshot.load(for: now)),
            DailyEntry(date: midnight, snapshot: DailySnapshot.load(for: now).cleared(for: midnight)),
        ]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

/// An action widget shows nothing that changes.
struct StaticProvider: TimelineProvider {
    struct Entry: TimelineEntry {
        let date = Date()
    }

    func placeholder(in _: Context) -> Entry {
        Entry()
    }

    func getSnapshot(in _: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry()], policy: .never))
    }
}

/// The app's asset colours, which aren't available to the extension.
enum WidgetColor {
    static let brand = Color(red: 79 / 255, green: 124 / 255, blue: 225 / 255)
    static let protein = Color(red: 1.0, green: 0.706, blue: 0.327)
    static let carbohydrate = Color(red: 0.475, green: 0.884, blue: 1.0)
    static let fat = Color(red: 0.815, green: 0.546, blue: 1.0)
}

struct ProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.2))
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geometry.size.width * progress))
                    .opacity(progress > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
    }
}

struct MacroBar: View {
    let name: String
    let value: Int
    let goal: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).font(.caption).foregroundStyle(color)
                Spacer()
                Text("\(value) / \(goal) g")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressBar(progress: DailySnapshot.progress(value, of: goal), color: color, height: 7)
        }
    }
}

extension DailySnapshot {
    /// "420 left", or how far over the goal the day is.
    var remainingText: String {
        caloriesLeft >= 0 ? "\(caloriesLeft.formatted()) left" : "\((-caloriesLeft).formatted()) over"
    }
}
