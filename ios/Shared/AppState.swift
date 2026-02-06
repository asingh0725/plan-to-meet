import Foundation
import Combine

/// Shared app state accessible from both main app and iMessage extension via App Group
final class AppState: ObservableObject {
    static let shared = AppState()

    private let defaults: UserDefaults

    @Published var sessionId: String
    @Published var displayName: String
    @Published var calendarEnabled: Bool

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
    }

    func updateDisplayName(_ name: String) {
        displayName = name
        defaults.set(name, forKey: AppConstants.Keys.displayName)
    }

    func updateCalendarEnabled(_ enabled: Bool) {
        calendarEnabled = enabled
        defaults.set(enabled, forKey: AppConstants.Keys.calendarEnabled)
    }

    /// Returns the display name or a default fallback
    var displayNameOrDefault: String {
        displayName.isEmpty ? "Anonymous" : displayName
    }
}
