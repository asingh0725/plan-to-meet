import Foundation
import Combine
import UserNotifications

/// Shared app state accessible from both main app and iMessage extension via App Group
final class AppState: ObservableObject {
    static let shared = AppState()

    private let defaults: UserDefaults

    @Published var sessionId: String
    @Published var displayName: String
    @Published var calendarEnabled: Bool
    @Published var hasCompletedOnboarding: Bool
    @Published var pushNotificationsEnabled: Bool
    @Published var pushToken: String?

    private init() {
        // Use App Group shared UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupId) {
            self.defaults = sharedDefaults
        } else {
            // Fallback to standard defaults if App Group not available
            self.defaults = UserDefaults.standard
        }

        // Load or create session ID
        if let existing = defaults.string(forKey: AppConstants.Keys.sessionId), !existing.isEmpty {
            self.sessionId = existing
        } else {
            let newId = UUID().uuidString.lowercased()
            defaults.set(newId, forKey: AppConstants.Keys.sessionId)
            self.sessionId = newId
        }

        // Load display name
        self.displayName = defaults.string(forKey: AppConstants.Keys.displayName) ?? ""

        // Load calendar preference
        self.calendarEnabled = defaults.bool(forKey: AppConstants.Keys.calendarEnabled)

        // Load onboarding completion state
        self.hasCompletedOnboarding = defaults.bool(forKey: AppConstants.Keys.hasCompletedOnboarding)

        // Load push notification preference
        self.pushNotificationsEnabled = defaults.bool(forKey: AppConstants.Keys.pushNotificationsEnabled)
    }

    func updateDisplayName(_ name: String) {
        displayName = name
        defaults.set(name, forKey: AppConstants.Keys.displayName)
    }

    func updateCalendarEnabled(_ enabled: Bool) {
        calendarEnabled = enabled
        defaults.set(enabled, forKey: AppConstants.Keys.calendarEnabled)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: AppConstants.Keys.hasCompletedOnboarding)
    }

    // MARK: - Push Notifications

    /// Requests APNs authorization and registers with Apple if granted.
    func requestPushNotifications(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.pushNotificationsEnabled = granted
                self?.defaults.set(granted, forKey: AppConstants.Keys.pushNotificationsEnabled)
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                completion(granted)
            }
        }
    }

    /// Called by AppDelegate when APNs returns a device token.
    /// Persists the token and registers it with Supabase.
    func onPushTokenReceived(_ token: String) {
        pushToken = token
        let sid = sessionId
        Task {
            try? await SupabaseAPI.registerPushToken(sessionId: sid, token: token)
        }
    }

    /// Returns the display name or a default fallback
    var displayNameOrDefault: String {
        displayName.isEmpty ? "Anonymous" : displayName
    }
}
