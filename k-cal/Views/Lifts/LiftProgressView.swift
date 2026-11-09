//
//  LiftProgressView.swift
//  k-cal
//
//  Your numbers, your estimated strength over time, and how much each muscle is getting.
//

import Charts
import SwiftData
import SwiftUI

struct LiftProgressView: View {
    let plan: LiftPlan

    @Environment(\.modelContext) private var context
    @Query private var maxes: [LiftMax]
    @Query(sort: \WorkoutLog.date) private var logs: [WorkoutLog]
    @State private var lift = AnchorLift.bench

    private struct Point: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    private var points: [Point] {
        logs.compactMap { log in
            let best = log.sets.filter { $0.exerciseID == lift.exerciseID }.map(\.estimatedMax).max()
            return best.map { Point(date: log.date, value: $0.rounded()) }
        }
    }

    /// Hard sets per muscle over the last seven days.
    private var weeklySets: [(muscle: Muscle, sets: Int)] {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        var counts: [Muscle: Int] = [:]
        for log in logs where log.date >= cutoff {
            for set in log.sets {
                if let muscle = ExerciseCatalog.exercise(set.exerciseID)?.muscle { counts[muscle, default: 0] += 1 }
            }
        }
        return Muscle.allCases.map { ($0, counts[$0] ?? 0) }
    }

    var body: some View {
        let profile = plan.profile(maxes: maxes)
        List {
            Section {
                Picker("Lift", selection: $lift) {
                    ForEach(AnchorLift.allCases) { Text($0.title).tag($0) }
                }
                if points.count >= 2 {
                    Chart(points) { point in
                        LineMark(x: .value("Date", point.date), y: .value(plan.unit, point.value))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.brand)
                        PointMark(x: .value("Date", point.date), y: .value(plan.unit, point.value))
                            .foregroundStyle(Theme.brand)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 180)
                } else {
                    Text("Log \(lift.title) twice to see your trend.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Estimated 1RM")
            }
            .listRowBackground(Theme.card)
            Section {
                ForEach(AnchorLift.allCases) { anchor in
                    let known = profile.maxes[anchor.exerciseID]
                    LabeledContent(anchor.title, value: LiftFormat.weight(profile.anchorMax(anchor).rounded(), unit: plan.unit) + (known == nil ? " est." : ""))
                }
                LabeledContent("Bodyweight", value: LiftFormat.weight(plan.bodyweight, unit: plan.unit))
            } header: {
                Text("One-rep maxes")
            } footer: {
                Text("These update when you beat them, and at every rep test.")
            }
            .listRowBackground(Theme.card)
            Section {
                ForEach(weeklySets, id: \.muscle) { entry in
                    HStack {
                        Text(entry.muscle.rawValue).font(.subheadline).frame(width: 92, alignment: .leading)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.brand.opacity(0.14))
                                Capsule().fill(Theme.brand).frame(width: geometry.size.width * min(Double(entry.sets) / 20, 1))
                            }
                        }
                        .frame(height: 8)
                        Text("\(entry.sets)").font(.caption).monospacedDigit().frame(width: 24, alignment: .trailing)
                    }
                }
            } header: {
                Text("Sets in the last 7 days")
            } footer: {
                Text("For size, most muscles grow well on 10 to 20 hard sets a week.")
            }
            .listRowBackground(Theme.card)
        }
        .themedList()
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
}
