//  ToggleHabitIntent.swift — lets a tap in the widget tick a habit (iOS 17+).
//  The tap is queued in the App Group; the web app applies it next time it runs.
import AppIntents
import WidgetKit

@available(iOS 17.0, *)
struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle habit"
    static var description = IntentDescription("Marks a habit done or not done for today.")

    @Parameter(title: "Habit ID") var habitId: String
    @Parameter(title: "Day") var day: String

    init() {}
    init(habitId: String, day: String) { self.habitId = habitId; self.day = day }

    func perform() async throws -> some IntentResult {
        SharedStore.appendToggle(type: "habit", id: habitId, key: day)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(iOS 17.0, *)
struct CompleteEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark event done"

    @Parameter(title: "Event ID") var eventId: String
    @Parameter(title: "Day") var day: String

    init() {}
    init(eventId: String, day: String) { self.eventId = eventId; self.day = day }

    func perform() async throws -> some IntentResult {
        SharedStore.appendToggle(type: "event", id: eventId, key: day)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
