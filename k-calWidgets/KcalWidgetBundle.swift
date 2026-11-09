//
//  KcalWidgetBundle.swift
//  k-calWidgets
//

import SwiftUI
import WidgetKit

@main
struct KcalWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyCaloriesWidget()
        CalorieRingWidget()
        DailyMacrosWidget()
        QuickScanWidget()
        QuickSnapWidget()
        QuickAddWidget()
        NextWorkoutWidget()
    }
}
