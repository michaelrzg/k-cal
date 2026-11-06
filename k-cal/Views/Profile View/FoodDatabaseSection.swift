//
//  FoodDatabaseSection.swift
//  k-cal
//
//  What's in the on-device food database, and the control for fetching new foods.
//

import SwiftUI

struct FoodDatabaseSection: View {
    @AppStorage(FoodUpdater.autoUpdateKey) private var updatesAutomatically = true
    private let updater = FoodUpdater.shared

    private var totalFoods: Int {
        updater.bundledFoods + updater.downloadedFoods
    }

    var body: some View {
        Section {
            LabeledContent("Foods on this phone", value: totalFoods.formatted())
            LabeledContent("Added by updates", value: updater.downloadedFoods.formatted())
            LabeledContent("Last checked") {
                if let lastChecked = updater.lastChecked {
                    Text(lastChecked, format: .dateTime.month().day().hour().minute())
                } else {
                    Text("Never")
                }
            }
            Toggle("Update automatically on Wi-Fi", isOn: $updatesAutomatically).tint(Theme.brand)
            if updater.isUpdating {
                HStack {
                    ProgressView()
                    Text(updater.status ?? "Updating...")
                        .font(.subheadline)
                        .accessibilityIdentifier("food-update-status")
                    Spacer()
                    Button("Stop") { updater.cancel() }
                        .buttonStyle(.borderless)
                }
            } else {
                Button("Check for New Foods") { updater.update() }
            }
            if let failure = updater.failure {
                Text(failure)
                    .font(.subheadline)
                    .foregroundStyle(Theme.brand)
            }
        } header: {
            Text("Food Database")
        } footer: {
            Text("Foods are stored on your phone and work offline. Each day of updates downloads about 25-45 MB.")
        }
        .onAppear { updater.refreshCounts() }
    }
}
