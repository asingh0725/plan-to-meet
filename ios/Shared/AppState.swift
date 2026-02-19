import Foundation
import Combine
import UserNotifications

/// Shared app state accessible from both main app and iMessage extension via App Group.
///
/// Session ID and display name are synced to iCloud Key-Value Store so they
/// survive device restores and transfers. The iCloud value wins on first launch
/// after a reinstall, keeping the user's poll history intact.
final class AppState: ObservableObject {
    static let shared = AppState()

    private let defaults: UserDefaults
    private let icloud = NSUbiquitousKeyValueStore.default

    @Published var sessionId: String
    @Published var displayName: String
    @Published var calendarEnabled: Bool
    @Published var hasCompletedOnboarding: Bool
    @Published var pushNotificationsEnabled: Bool
    @Published var pushToken: String?

    private init() {
        // Use App Group shared UserDefaults (shared with Messages extension)
        if let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupId) {
            self.defaults = sharedDefaults
        } else {
            self.defaults = UserDefaults.standard
        }

        // ---------- Session ID ----------
        // Priority: iCloud → existing local → generate new
        let icloudSession = icloud.string(forKey: AppConstants.Keys.sessionId)
        let localSession = defaults.string(forKey: AppConstants.Keys.sessionId)

        if let existing = localSession, !existing.isEmpty {
            // Local value exists. If iCloud has a different (older) value, adopt local
            // and push it to iCloud so all devices eventually converge.
            self.sessionId = existing
            if icloudSession == nil || icloudSession!.isEmpty {
                icloud.set(existing, forKey: AppConstants.Keys.sessionId)
            }
        } else if let fromCloud = icloudSession, !fromCloud.isEmpty {
            // Fresh install / reinstall — restore session from iCloud
            self.sessionId = fromCloud
            defaults.set(fromCloud, forKey: AppConstants.Keys.sessionId)
        } else {
            // Brand new user: generate, persist locally and to iCloud
            let newId = UUID().uuidString.lowercased()
            defaults.set(newId, forKey: AppConstants.Keys.sessionId)
            icloud.set(newId, forKey: AppConstants.Keys.sessionId)
            self.sessionId = newId
        }

        // ---------- Display Name ----------
        let localName = defaults.string(forKey: AppConstants.Keys.displayName) ?? ""
        let icloudName = icloud.string(forKey: AppConstants.Keys.displayName) ?? ""
        // Prefer whichever is non-empty; local wins if both set
        self.displayName = localName.isEmpty ? icloudName : localName
        if !self.displayName.isEmpty {
            icloud.set(self.displayName, forKey: AppConstants.Keys.displayName)
        }

        // ---------- Other preferences ----------
        self.calendarEnabled = defaults.bool(forKey: AppConstants.Keys.calendarEnabled)
        self.hasCompletedOnboarding = defaults.bool(forKey: AppConstants.Keys.hasCompletedOnboarding)
        self.pushNotificationsEnabled = defaults.bool(forKey: AppConstants.Keys.pushNotificationsEnabled)

        // Sync iCloud KV store on launch
        icloud.synchronize()

        // Observe external iCloud changes (e.g. another device updates the name)
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: icloud,
            queue: .main
        ) { [weak self] notification in
            self?.handleICloudChange(notification)
        }
    }

    // MARK: - iCloud Change Handler

    private func handleICloudChange(_ notification: Notification) {
        guard let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }

        for key in keys {
            switch key {
            case AppConstants.Keys.displayName:
                if let name = icloud.string(forKey: key), !name.isEmpty, name != displayName {
                    displayName = name
                    defaults.set(name, forKey: key)
                }
            default:
                break
            }
        }
    }

    // MARK: - Mutators

    func updateDisplayName(_ name: String) {
        displayName = name
        defaults.set(name, forKey: AppConstants.Keys.displayName)
        icloud.set(name, forKey: AppConstants.Keys.displayName)
        icloud.synchronize()
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
    func onPushTokenReceived(_ token: String) {
        pushToken = token
        let sid = sessionId
        Task {
            try? await SupabaseAPI.registerPushToken(sessionId: sid, token: token)
        }
    }

    // MARK: - Computed

    var displayNameOrDefault: String {
        displayName.isEmpty ? "Anonymous" : displayName
    }
}
