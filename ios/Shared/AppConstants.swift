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
        static let eventPassBalance = "PlanToMeet_EventPassBalance"
        static let hasGrantedStarterEventPasses = "PlanToMeet_HasGrantedStarterEventPasses"
        static let processedStoreTransactions = "PlanToMeet_ProcessedStoreTransactions"
    }

    enum Premium {
        static let starterEventPasses = 3
        static let organizerNoteLimit = 280

        static let singleProductId = "com.aviraj.plantomeet.eventpass.single"
        static let fivePackProductId = "com.aviraj.plantomeet.eventpass.five"
        static let twentyPackProductId = "com.aviraj.plantomeet.eventpass.twenty"

        static let productIds = [
            singleProductId,
            fivePackProductId,
            twentyPackProductId
        ]

        static func eventPassCount(for productId: String) -> Int? {
            switch productId {
            case singleProductId:
                return 1
            case fivePackProductId:
                return 5
            case twentyPackProductId:
                return 20
            default:
                return nil
            }
        }
    }
}
