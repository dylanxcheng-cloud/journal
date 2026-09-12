//  DaybookWidget.swift — home-screen widget: small, medium, large (iPhone + iPad) and extra large (iPad).
//  Mirrors widget.html: progress ring, remaining habits, next events grouped by day.
import SwiftUI
import WidgetKit

struct DaybookWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DaybookWidget", provider: Provider()) { entry in
            DaybookWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Daybook")
        .description("Today's habits and what's coming up.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

private let blue = Color(red: 0.10, green: 0.45, blue: 0.91)

extension Color {
    init(hex: String) { let (r, g, b) = hex.hexRGB; self.init(red: r, green: g, blue: b) }
}

struct DaybookWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry
    var snap: Snapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        default: large
        }
    }

    // MARK: pieces

    var ring: some View {
        let ratio = snap.today.total == 0 ? 0 : Double(snap.today.done) / Double(snap.today.total)
        return ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 5)
            Circle().trim(from: 0, to: ratio).stroke(blue, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
            Text(snap.today.total == 0 ? "–" : "\(snap.today.done)/\(snap.today.total)").font(.system(size: 12, weight: .bold))
        }
        .frame(width: 44, height: 44)
    }

    var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.date, format: .dateTime.weekday(.wide)).font(.headline)
                Text(entry.date, format: .dateTime.month(.wide).day()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            ring
        }
    }

    func habitRow(_ h: Snapshot.Habit) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().strokeBorder(h.done ? Color.clear : Color.secondary, lineWidth: 1.5)
                if h.done { Circle().fill(Color(hex: h.color)); Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white) }
            }
            .frame(width: 18, height: 18)
            Text(h.name).font(.footnote.weight(.medium)).strikethrough(h.done).foregroundStyle(h.done ? .secondary : .primary).lineLimit(1)
            Spacer(minLength: 0)
            if h.streak > 0 { Text("\(h.streak)").font(.caption2).foregroundStyle(.orange) }
        }
    }

    @ViewBuilder func habitButton(_ h: Snapshot.Habit) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleHabitIntent(habitId: h.id, day: snap.today.date)) { habitRow(h) }.buttonStyle(.plain)
        } else {
            habitRow(h)
        }
    }

    func eventRow(_ u: Snapshot.Upcoming) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: u.color)).frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(u.title).font(.footnote.weight(.medium)).lineLimit(1)
                Text(u.allDay ? "All day" : u.at.formatted(date: .omitted, time: .shortened) + (u.from.isEmpty ? "" : " · \(u.from)")).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if #available(iOS 17.0, *) {
                Button(intent: CompleteEventIntent(eventId: u.eventId, day: u.key)) {
                    Image(systemName: "circle").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
        }
    }

    func dayLabel(_ u: Snapshot.Upcoming) -> String {
        if Calendar.current.isDateInToday(u.at) { return "Today" }
        if Calendar.current.isDateInTomorrow(u.at) { return "Tomorrow" }
        return u.at.formatted(.dateTime.weekday(.wide))
    }

    @ViewBuilder func eventsList(max: Int) -> some View {
        let items = Array(snap.upcoming.prefix(max))
        if items.isEmpty {
            Text("Nothing coming up").font(.caption).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, u in
                    if i == 0 || dayLabel(items[i - 1]) != dayLabel(u) {
                        Text(dayLabel(u).uppercased()).font(.caption2.weight(.bold)).foregroundStyle(blue).padding(.top, i == 0 ? 0 : 4)
                    }
                    eventRow(u)
                }
            }
        }
    }

    // MARK: families

    var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(entry.date, format: .dateTime.weekday(.abbreviated)).font(.caption.weight(.semibold)).foregroundStyle(.secondary); Spacer(); ring }
            if let next = snap.upcoming.first {
                Text("NEXT").font(.caption2.weight(.bold)).foregroundStyle(blue)
                Text(next.title).font(.footnote.weight(.medium)).lineLimit(2)
                Text(next.allDay ? dayLabel(next) : next.at.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(snap.today.total == 0 ? "Add habits in Daybook" : "\(snap.today.total - snap.today.done) habits left").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "daybook://today"))
    }

    var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                header
                let left = snap.today.habits.filter { !$0.done }
                if left.isEmpty { Text(snap.today.total == 0 ? "No habits yet" : "All done today").font(.caption).foregroundStyle(.secondary) }
                ForEach(left.prefix(3)) { habitButton($0) }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                Text("COMING UP").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                eventsList(max: 3)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .widgetURL(URL(string: "daybook://today"))
    }

    var large: some View {
        let isXL = family == .systemExtraLarge
        return HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                header
                Text("HABITS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                if snap.today.habits.isEmpty { Text("No habits yet").font(.caption).foregroundStyle(.secondary) }
                ForEach(snap.today.habits.prefix(isXL ? 10 : 5)) { habitButton($0) }
                if !isXL {
                    Text("COMING UP").font(.caption2.weight(.bold)).foregroundStyle(.secondary).padding(.top, 4)
                    eventsList(max: 4)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            if isXL {
                VStack(alignment: .leading, spacing: 4) {
                    Text("COMING UP").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    eventsList(max: 9)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .widgetURL(URL(string: "daybook://today"))
    }
}
