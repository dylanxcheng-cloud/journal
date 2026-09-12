//  SharedStore.swift — App Group storage shared by the app and the widget extension.
//  Add this file to BOTH the App target and the DaybookWidget target.
import Foundation

enum SharedStore {
    /// Must match the App Group enabled on both targets in Xcode → Signing & Capabilities.
    static let appGroup = "group.com.daybook.app"
    static let snapshotKey = "daybook.snapshot.v1"
    static let pendingKey = "daybook.pendingToggles"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func saveSnapshot(_ json: String) {
        defaults?.set(json, forKey: snapshotKey)
    }

    static func loadSnapshot() -> Snapshot? {
        guard let json = defaults?.string(forKey: snapshotKey), let data = json.data(using: .utf8) else { return nil }
        return try? Snapshot.decoder.decode(Snapshot.self, from: data)
    }

    /// Called from widget intents. Records the tap for the app and flips the stored snapshot so the
    /// widget reflects the change immediately, before the app has run again.
    static func appendToggle(type: String, id: String, key: String) {
        var list = defaults?.array(forKey: pendingKey) as? [[String: Any]] ?? []
        list.append(["type": type, "id": id, "key": key, "at": ISO8601DateFormatter().string(from: Date())])
        defaults?.set(list, forKey: pendingKey)

        if var snap = loadSnapshot() {
            if type == "habit", let i = snap.today.habits.firstIndex(where: { $0.id == id }), snap.today.date == key {
                snap.today.habits[i].done.toggle()
                snap.today.done = snap.today.habits.filter { $0.done }.count
            } else if type == "event" {
                snap.upcoming.removeAll { $0.eventId == id && $0.key == key }
            }
            if let data = try? Snapshot.encoder.encode(snap), let json = String(data: data, encoding: .utf8) {
                saveSnapshot(json)
            }
        }
    }

    /// Returns queued widget taps and clears the queue. Called by the app on launch/resume.
    static func drainPendingToggles() -> [[String: Any]] {
        let list = defaults?.array(forKey: pendingKey) as? [[String: Any]] ?? []
        defaults?.removeObject(forKey: pendingKey)
        return list
    }
}
