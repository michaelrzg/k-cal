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

/// The app's palette. Its asset catalog isn't available to the extension, so these mirror it.
enum WidgetColor {
    static let background = adaptive(0xF4F2EC, 0x1E1D1B)
    static let brand = adaptive(0xB4553A, 0xDD8866)
    static let protein = adaptive(0x96671F, 0xDBAA60)
    static let carbohydrate = adaptive(0x4C7157, 0x93B79A)
    static let fat = adaptive(0x7A5880, 0xBB9CC0)

    private static func adaptive(_ light: Int, _ dark: Int) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? color(dark) : color(light) })
    }

    private static func color(_ hex: Int) -> UIColor {
        UIColor(red: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
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
