import Foundation
import Combine
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif
#if canImport(StoreKit) && !APP_EXTENSION
import StoreKit
#endif

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
    @Published var eventPassBalance: Int

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
        let resolvedDisplayName = localName.isEmpty ? icloudName : localName
        self.displayName = resolvedDisplayName
        if !resolvedDisplayName.isEmpty {
            icloud.set(resolvedDisplayName, forKey: AppConstants.Keys.displayName)
        }

        // ---------- Other preferences ----------
        self.calendarEnabled = defaults.bool(forKey: AppConstants.Keys.calendarEnabled)
        self.hasCompletedOnboarding = defaults.bool(forKey: AppConstants.Keys.hasCompletedOnboarding)
        self.pushNotificationsEnabled = defaults.bool(forKey: AppConstants.Keys.pushNotificationsEnabled)
        self.eventPassBalance = max(
            defaults.object(forKey: AppConstants.Keys.eventPassBalance) as? Int
                ?? icloud.longLong(forKey: AppConstants.Keys.eventPassBalance).clampedToInt,
            0
        )

        let hasGrantedStarterPasses =
            defaults.bool(forKey: AppConstants.Keys.hasGrantedStarterEventPasses)
            || icloud.bool(forKey: AppConstants.Keys.hasGrantedStarterEventPasses)
        if hasGrantedStarterPasses {
            defaults.set(true, forKey: AppConstants.Keys.hasGrantedStarterEventPasses)
            icloud.set(true, forKey: AppConstants.Keys.hasGrantedStarterEventPasses)
        } else {
            grantStarterEventPasses()
        }

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
            case AppConstants.Keys.eventPassBalance:
                let newBalance = max(icloud.longLong(forKey: key).clampedToInt, 0)
                if newBalance != eventPassBalance {
                    eventPassBalance = newBalance
                    defaults.set(newBalance, forKey: key)
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

    // MARK: - Premium Event Passes

    var hasEventPasses: Bool {
        eventPassBalance > 0
    }

    func addEventPasses(_ count: Int) {
        guard count > 0 else { return }
        setEventPassBalance(eventPassBalance + count)
    }

    @discardableResult
    func consumeEventPasses(_ count: Int = 1) -> Bool {
        guard count > 0, eventPassBalance >= count else { return false }
        setEventPassBalance(eventPassBalance - count)
        return true
    }

    func refundEventPasses(_ count: Int = 1) {
        addEventPasses(count)
    }

    // MARK: - Push Notifications

    /// Requests APNs authorization and registers with Apple if granted.
    func requestPushNotifications(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.pushNotificationsEnabled = granted
                self?.defaults.set(granted, forKey: AppConstants.Keys.pushNotificationsEnabled)
                if granted {
                    self?.registerForRemoteNotificationsIfSupported()
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

    private func registerForRemoteNotificationsIfSupported() {
        #if canImport(UIKit) && !APP_EXTENSION
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    private func grantStarterEventPasses() {
        defaults.set(true, forKey: AppConstants.Keys.hasGrantedStarterEventPasses)
        icloud.set(true, forKey: AppConstants.Keys.hasGrantedStarterEventPasses)
        setEventPassBalance(eventPassBalance + AppConstants.Premium.starterEventPasses)
    }

    private func setEventPassBalance(_ newValue: Int) {
        let clamped = max(newValue, 0)
        eventPassBalance = clamped
        defaults.set(clamped, forKey: AppConstants.Keys.eventPassBalance)
        icloud.set(Int64(clamped), forKey: AppConstants.Keys.eventPassBalance)
        icloud.synchronize()
    }
}

private extension Int64 {
    var clampedToInt: Int {
        if self > Int64(Int.max) { return Int.max }
        if self < Int64(Int.min) { return Int.min }
        return Int(self)
    }
}

#if canImport(StoreKit) && !APP_EXTENSION
@MainActor
final class EventPassStore: ObservableObject {
    static let shared = EventPassStore()

    struct PackageDescriptor: Identifiable {
        let productId: String
        let title: String
        let subtitle: String
        let eventPassCount: Int

        var id: String { productId }
    }

    @Published private(set) var products: [Product] = []
    @Published var isLoadingProducts = false
    @Published var isPurchasing = false
    @Published var errorMessage: String?
    @Published var purchaseMessage: String?

    let packages: [PackageDescriptor] = [
        PackageDescriptor(
            productId: AppConstants.Premium.singleProductId,
            title: "Single Event Pass",
            subtitle: "Upgrade one event with premium organizer tools.",
            eventPassCount: 1
        ),
        PackageDescriptor(
            productId: AppConstants.Premium.fivePackProductId,
            title: "Host Pack",
            subtitle: "Best for parents, organizers, and repeat planners.",
            eventPassCount: 5
        ),
        PackageDescriptor(
            productId: AppConstants.Premium.twentyPackProductId,
            title: "Season Pack",
            subtitle: "For clubs, teams, and heavy repeat scheduling.",
            eventPassCount: 20
        )
    ]

    private let defaults: UserDefaults
    private var processedTransactionIds: Set<String>
    private var updatesTask: Task<Void, Never>?

    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupId) ?? .standard
        processedTransactionIds = Set(defaults.stringArray(forKey: AppConstants.Keys.processedStoreTransactions) ?? [])
        updatesTask = observeTransactionUpdates()

        Task {
            await refreshProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func product(for productId: String) -> Product? {
        products.first(where: { $0.id == productId })
    }

    func refreshProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: AppConstants.Premium.productIds)
            products = fetched.sorted { lhs, rhs in
                (AppConstants.Premium.eventPassCount(for: lhs.id) ?? 0) < (AppConstants.Premium.eventPassCount(for: rhs.id) ?? 0)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ package: PackageDescriptor) async {
        purchaseMessage = nil

        guard let product = product(for: package.productId) else {
            errorMessage = "The App Store products are not available yet. Add the Event Pass products in App Store Connect and try again."
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                apply(transaction)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                purchaseMessage = "Purchase pending approval."
            @unknown default:
                errorMessage = "Purchase could not be completed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.verified(result)
                    self.apply(transaction)
                    await transaction.finish()
                } catch {
                    continue
                }
            }
        }
    }

    private func apply(_ transaction: Transaction) {
        let transactionId = String(transaction.id)
        guard !processedTransactionIds.contains(transactionId) else { return }
        guard let passCount = AppConstants.Premium.eventPassCount(for: transaction.productID) else { return }

        processedTransactionIds.insert(transactionId)
        defaults.set(Array(processedTransactionIds), forKey: AppConstants.Keys.processedStoreTransactions)
        AppState.shared.addEventPasses(passCount)
        purchaseMessage = "Added \(passCount) Event Pass\(passCount == 1 ? "" : "es")."
        errorMessage = nil
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "The App Store could not verify this purchase."
            }
        }
    }
}
#endif
