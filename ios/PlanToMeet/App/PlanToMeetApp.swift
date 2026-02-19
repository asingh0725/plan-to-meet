import SwiftUI
import UserNotifications

// MARK: - Sentry Setup
// To enable crash reporting:
// 1. In Xcode: File → Add Package Dependencies
//    URL: https://github.com/getsentry/sentry-cocoa
//    Version: 8.x.x
// 2. Add SENTRY_DSN to ios/PlanToMeet/Secrets.xcconfig
//
// Once the Swift Package is added the #if canImport(Sentry) block below
// activates automatically — no further code changes needed.

#if canImport(Sentry)
import Sentry
#endif

// MARK: - App Delegate

/// Handles APNs token registration callbacks and foreground notification display.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task { @MainActor in
            AppState.shared.onPushTokenReceived(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    // Show notification banner even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
}

// MARK: - App

@main
struct PlanToMeetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    init() {
        configureSentry()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .fullScreenCover(isPresented: .init(
                    get: { !appState.hasCompletedOnboarding },
                    set: { _ in }
                )) {
                    OnboardingView()
                        .environmentObject(appState)
                }
        }
    }

    private func configureSentry() {
        #if canImport(Sentry)
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
              !dsn.isEmpty else { return }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = Bundle.main.object(forInfoDictionaryKey: "SENTRY_ENVIRONMENT") as? String ?? "production"
            options.tracesSampleRate = 0.1
            options.enableCrashHandler = true
            options.enableSwiftAsyncStacktraces = true
        }
        #endif
    }
}
