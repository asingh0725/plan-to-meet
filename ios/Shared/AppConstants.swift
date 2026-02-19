import Foundation

enum AppConstants {
    static let appGroupId = "group.com.aviraj.plantomeet"
    static let webBaseURL = "https://plantomeet.app"

    // UserDefaults keys
    enum Keys {
        static let sessionId = "PlanToMeet_SessionId"
        static let displayName = "PlanToMeet_DisplayName"
        static let calendarEnabled = "PlanToMeet_CalendarEnabled"
        static let hasCompletedOnboarding = "PlanToMeet_HasCompletedOnboarding"
        static let pushNotificationsEnabled = "PlanToMeet_PushNotificationsEnabled"
    }
}
