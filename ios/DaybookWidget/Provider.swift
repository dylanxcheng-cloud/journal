//  Provider.swift — turns the shared snapshot into a WidgetKit timeline.
import WidgetKit

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot
    var isPlaceholder = false
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snapshot: .sample, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snapshot: SharedStore.loadSnapshot() ?? .sample, isPlaceholder: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        guard let snap = SharedStore.loadSnapshot() else {
            completion(Timeline(entries: [Entry(date: now, snapshot: .sample, isPlaceholder: true)], policy: .after(now.addingTimeInterval(1800))))
            return
        }
        // One entry now, then one at every moment the JS side said the view changes
        // (midnight, each event time). Past-event rows are dropped per entry.
        var entries = [Entry(date: now, snapshot: snap)]
        for t in snap.refreshAt where t > now {
            var s = snap
            s.upcoming.removeAll { $0.at <= t && !$0.allDay }
            entries.append(Entry(date: t, snapshot: s))
        }
        let next = snap.refreshAt.first(where: { $0 > now }) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}
