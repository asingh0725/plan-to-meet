import EventKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    @State private var displayNameInput: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AuthKitBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        profileSection
                        notificationsSection
                        calendarSection
                        aboutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            displayNameInput = appState.displayName
            viewModel.checkCalendarStatus()
            viewModel.checkPushStatus()
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Profile", icon: "person.circle")

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)

                    TextField("Enter your name", text: $displayNameInput)
                        .font(.body)
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Theme.elevatedBackground)
                        .cornerRadius(Theme.cornerRadiusMedium)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .onSubmit {
                            appState.updateDisplayName(displayNameInput)
                        }
                        .onChange(of: displayNameInput) { newValue in
                            appState.updateDisplayName(newValue)
                        }

                    Text("This name will be shown to others in polls you respond to")
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(16)
            .cardStyle()
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Notifications", icon: "bell")

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Poll Activity Alerts")
                            .font(.body.weight(.medium))
                            .foregroundColor(Theme.textPrimary)

                        Text(pushStatusText)
                            .font(.caption)
                            .foregroundColor(pushStatusColor)
                    }

                    Spacer()

                    if viewModel.isRequestingPushAccess {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentBlue))
                    } else {
                        Toggle("", isOn: Binding(
                            get: { viewModel.isPushAuthorized },
                            set: { enabled in
                                if enabled {
                                    appState.requestPushNotifications { granted in
                                        viewModel.checkPushStatus()
                                    }
                                    viewModel.isRequestingPushAccess = true
                                } else {
                                    appState.pushNotificationsEnabled = false
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(Theme.accentBlue)
                        .disabled(viewModel.pushStatus == .denied || viewModel.pushStatus == .provisional)
                    }
                }
                .padding(16)

                Divider().background(Theme.border)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundColor(Theme.accentBlue)

                    Text("Get notified when your poll receives responses or a final time is chosen.")
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(16)

                if viewModel.pushStatus == .denied {
                    Divider().background(Theme.border)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("Open Settings to Enable")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .foregroundColor(Theme.accentBlue)
                        .padding(16)
                    }
                }
            }
            .cardStyle()
        }
    }

    private var pushStatusText: String {
        if viewModel.isPushAuthorized { return "Enabled" }
        switch viewModel.pushStatus {
        case .notDetermined: return "Not set up"
        case .denied: return "Disabled — enable in Settings"
        case .provisional: return "Provisional (silent)"
        default: return "Not available"
        }
    }

    private var pushStatusColor: Color {
        if viewModel.isPushAuthorized { return .green }
        switch viewModel.pushStatus {
        case .denied: return Theme.accentOrange
        default: return Theme.textTertiary
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Calendar", icon: "calendar")

            VStack(spacing: 0) {
                // Calendar toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connect Calendar")
                            .font(.body.weight(.medium))
                            .foregroundColor(Theme.textPrimary)

                        Text(calendarStatusText)
                            .font(.caption)
                            .foregroundColor(calendarStatusColor)
                    }

                    Spacer()

                    if viewModel.isRequestingAccess {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentBlue))
                    } else {
                        Toggle("", isOn: Binding(
                            get: { viewModel.isCalendarAuthorized },
                            set: { enabled in
                                if enabled {
                                    viewModel.requestCalendarAccess { granted in
                                        appState.updateCalendarEnabled(granted)
                                    }
                                } else {
                                    appState.updateCalendarEnabled(false)
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(Theme.accentBlue)
                        .disabled(viewModel.calendarStatus == .denied || viewModel.calendarStatus == .restricted)
                    }
                }
                .padding(16)

                Divider()
                    .background(Theme.border)

                // Info
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundColor(Theme.accentBlue)

                    Text("When enabled, your busy times will be shown while selecting availability. Your calendar data stays on your device.")
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(16)

                if viewModel.calendarStatus == .denied || viewModel.calendarStatus == .restricted {
                    Divider()
                        .background(Theme.border)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("Open Settings to Enable")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .foregroundColor(Theme.accentBlue)
                        .padding(16)
                    }
                }
            }
            .cardStyle()
        }
    }

    private var calendarStatusText: String {
        if viewModel.isCalendarAuthorized {
            return "Connected"
        }
        switch viewModel.calendarStatus {
        case .notDetermined:
            return "Not connected"
        case .denied, .restricted:
            return "Access denied - enable in Settings"
        default:
            if #available(iOS 17.0, *) {
                if viewModel.calendarStatus == .writeOnly {
                    return "Limited access - enable full access in Settings"
                }
            }
            return "Unknown status"
        }
    }

    private var calendarStatusColor: Color {
        if viewModel.isCalendarAuthorized {
            return .green
        }
        switch viewModel.calendarStatus {
        case .denied, .restricted:
            return Theme.accentOrange
        default:
            if #available(iOS 17.0, *) {
                if viewModel.calendarStatus == .writeOnly {
                    return Theme.accentOrange
                }
            }
            return Theme.textTertiary
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "About", icon: "info.circle")

            VStack(spacing: 0) {
                infoRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")

                Divider().background(Theme.border)

                infoRow(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            }
            .cardStyle()
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.leading, 4)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(16)
    }
}

// MARK: - View Model

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var calendarStatus: EKAuthorizationStatus = .notDetermined
    @Published var isRequestingAccess = false
    @Published var pushStatus: UNAuthorizationStatus = .notDetermined
    @Published var isRequestingPushAccess = false

    private let eventStore = EKEventStore()

    var isPushAuthorized: Bool {
        pushStatus == .authorized || pushStatus == .provisional
    }

    func checkPushStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.pushStatus = settings.authorizationStatus
                self?.isRequestingPushAccess = false
            }
        }
    }

    var isCalendarAuthorized: Bool {
        if calendarStatus == .authorized {
            return true
        }
        if #available(iOS 17.0, *) {
            return calendarStatus == .fullAccess
        }
        return false
    }

    func checkCalendarStatus() {
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        isRequestingAccess = true

        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isRequestingAccess = false
                    self?.checkCalendarStatus()
                    completion(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isRequestingAccess = false
                    self?.checkCalendarStatus()
                    completion(granted)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
