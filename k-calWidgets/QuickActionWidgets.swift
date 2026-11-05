//
//  QuickActionWidgets.swift
//  k-calWidgets
//

import SwiftUI
import WidgetKit

private struct QuickAction {
    let link: AppLink
    let title: String
    let symbol: String

    static let scan = QuickAction(link: .scan, title: "Scan", symbol: "barcode.viewfinder")
    static let snap = QuickAction(link: .snap, title: "Snap", symbol: "camera.fill")
    static let search = QuickAction(link: .search, title: "Search", symbol: "magnifyingglass")
    static let custom = QuickAction(link: .custom, title: "My Foods", symbol: "square.and.pencil")
}

/// Opens straight to one action. The Lock Screen version is a single icon.
private struct SingleActionView: View {
    @Environment(\.widgetFamily) private var family
    let action: QuickAction

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: action.symbol).font(.title2).widgetAccentable()
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: action.symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(WidgetColor.brand)
                Text(action.title).font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct QuickScanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickScan", provider: StaticProvider()) { _ in
            SingleActionView(action: .scan)
                .containerBackground(.background, for: .widget)
                .widgetURL(AppLink.scan.url)
        }
        .configurationDisplayName("Quick Scan")
        .description("Open the barcode scanner.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct QuickSnapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickSnap", provider: StaticProvider()) { _ in
            SingleActionView(action: .snap)
                .containerBackground(.background, for: .widget)
                .widgetURL(AppLink.snap.url)
        }
        .configurationDisplayName("Snap a Meal")
        .description("Estimate calories from a photo.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

/// All the ways to add food. Only medium and larger widgets can hold several tappable links.
struct QuickAddWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickAdd", provider: StaticProvider()) { _ in
            QuickAddView()
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Quick Add")
        .description("Scan, snap, search or pick one of your foods.")
        .supportedFamilies([.systemMedium])
    }
}

struct QuickAddView: View {
    private let actions: [QuickAction] = [.scan, .snap, .search, .custom]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(actions, id: \.link) { action in
                Link(destination: action.link.url) {
                    VStack(spacing: 6) {
                        Image(systemName: action.symbol)
                            .font(.title2)
                            .foregroundStyle(WidgetColor.brand)
                        Text(action.title)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WidgetColor.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}
