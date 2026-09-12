//  Snapshot.swift — Codable mirror of js/snapshot.js. Add to BOTH targets.
//  The JS side precomputes recurrence, streaks and refresh times; Swift only decodes and draws.
import Foundation

struct Snapshot: Codable {
    var version: Int
    var generatedAt: Date
    var today: Today
    var upcoming: [Upcoming]
    var refreshAt: [Date]
    var notifications: [Notification]

    struct Today: Codable {
        var date: String
        var done: Int
        var total: Int
        var habits: [Habit]
    }
    struct Habit: Codable, Identifiable {
        var id: String
        var name: String
        var color: String
        var done: Bool
        var streak: Int
    }
    struct Upcoming: Codable, Identifiable {
        var id: String { eventId + "|" + key }
        var eventId: String
        var key: String
        var title: String
        var from: String
        var time: String?
        var allDay: Bool
        var color: String
        var at: Date
    }
    struct Notification: Codable {
        var id: String
        var title: String
        var body: String
        var at: Date
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            if let date = f.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(s)"))
        }
        return d
    }()
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// Placeholder shown in the widget gallery and before the app has run once.
    static let sample = Snapshot(
        version: 1, generatedAt: Date(),
        today: Today(date: "", done: 1, total: 3, habits: [
            Habit(id: "a", name: "Read 10 pages", color: "#33b679", done: true, streak: 4),
            Habit(id: "b", name: "Morning run", color: "#8e24aa", done: false, streak: 0),
            Habit(id: "c", name: "Drink water", color: "#e67c73", done: false, streak: 2),
        ]),
        upcoming: [
            Upcoming(eventId: "e1", key: "", title: "Send Maria the report", from: "Maria", time: "16:30", allDay: false, color: "#039be5", at: Date().addingTimeInterval(3600)),
            Upcoming(eventId: "e2", key: "", title: "Call Mom", from: "", time: "19:00", allDay: false, color: "#f6bf26", at: Date().addingTimeInterval(86400)),
        ],
        refreshAt: [], notifications: [])
}

extension String {
    /// "#rrggbb" → SwiftUI Color components.
    var hexRGB: (Double, Double, Double) {
        var h = self.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        guard let n = UInt32(h, radix: 16) else { return (0.1, 0.45, 0.91) }
        return (Double((n >> 16) & 255) / 255, Double((n >> 8) & 255) / 255, Double(n & 255) / 255)
    }
}
