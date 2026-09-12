//  LockScreenWidget.swift — lock-screen (accessory) widgets. This is the native answer to the
//  "wallpaper" reminder: habits progress and the next event live on the lock screen itself.
import SwiftUI
import WidgetKit

struct DaybookLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DaybookLockScreen", provider: Provider()) { entry in
            LockScreenView(entry: entry).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Daybook · Next up")
        .description("Habit progress and your next event on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry
    var snap: Snapshot { entry.snapshot }
    var next: Snapshot.Upcoming? { snap.upcoming.first }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: snap.today.total == 0 ? 0 : Double(snap.today.done), in: 0...Double(max(snap.today.total, 1))) {
                Image(systemName: "checkmark")
            } currentValueLabel: {
                Text("\(snap.today.done)/\(snap.today.total)").font(.system(size: 12, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)
            .widgetURL(URL(string: "daybook://today"))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                if let n = next {
                    Text(n.allDay ? "Next · all day" : "Next · " + n.at.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                    Text(n.title).font(.headline).lineLimit(1)
                    if !n.from.isEmpty { Text(n.from).font(.caption2).foregroundStyle(.secondary) }
                } else {
                    Text("Daybook").font(.caption2).foregroundStyle(.secondary)
                    Text(snap.today.total == 0 ? "Nothing scheduled" : "\(snap.today.total - snap.today.done) habits left").font(.headline)
                }
            }
            .widgetURL(URL(string: "daybook://events"))
        default:
            if let n = next {
                Text("\(n.allDay ? "" : n.at.formatted(date: .omitted, time: .shortened) + " ")\(n.title)")
            } else {
                Text("Habits \(snap.today.done)/\(snap.today.total)")
            }
        }
    }
}
