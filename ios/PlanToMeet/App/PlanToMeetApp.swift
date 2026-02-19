import SwiftUI

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

@main
struct PlanToMeetApp: App {
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
