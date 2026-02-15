import StoreKit
import SwiftUI

struct AppClipRootView: View {
    @EnvironmentObject var appState: AppState
    @State private var pollId: String?
    @State private var showingAppStoreOverlay = false
    @State private var manualPollId: String = ""

    var body: some View {
        Group {
            if let pollId = pollId {
                AppClipPollView(
                    pollId: pollId,
                    onShowFullApp: { showingAppStoreOverlay = true }
                )
            } else {
                #if DEBUG
                DebugPollEntryView(manualPollId: $manualPollId, onSubmit: { id in
                    pollId = id
                })
                #else
                WaitingForPollView()
                #endif
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appClipPollIdReceived)) { notification in
            if let id = notification.userInfo?["pollId"] as? String {
                pollId = id
            }
        }
        .onAppear {
            applyDebugLaunchOverridesIfNeeded()
        }
        .appStoreOverlay(isPresented: $showingAppStoreOverlay) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
    }

    private func applyDebugLaunchOverridesIfNeeded() {
        #if DEBUG
        guard pollId == nil else { return }

        let args = ProcessInfo.processInfo.arguments
        if let pollArgIndex = args.firstIndex(of: "-pollId"), pollArgIndex + 1 < args.count {
            let id = args[pollArgIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            if !id.isEmpty {
                pollId = id
                return
            }
        }

        let env = ProcessInfo.processInfo.environment
        if let id = env["APP_CLIP_POLL_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            pollId = id
        }
        #endif
    }
}

struct WaitingForPollView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentBlue))
                .scaleEffect(1.2)

            Text("Loading poll...")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AuthKitBackground())
    }
}

#if DEBUG
struct DebugPollEntryView: View {
    @Binding var manualPollId: String
    var onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(Theme.accentBlue)

            Text("PlanToMeet App Clip")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            Text("Debug Mode")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Theme.cardBackground)
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 8) {
                Text("Enter Poll ID to test:")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)

                TextField("Poll ID", text: $manualPollId)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Theme.cardBackground)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 32)

            Button {
                if !manualPollId.isEmpty {
                    onSubmit(manualPollId)
                }
            } label: {
                Text("Load Poll")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(manualPollId.isEmpty ? Theme.buttonDisabledBackground : Theme.accentBlue)
                    .cornerRadius(12)
            }
            .disabled(manualPollId.isEmpty)
            .padding(.horizontal, 32)

            Spacer()

            Text("In production, the poll ID comes from the URL")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AuthKitBackground())
    }
}
#endif

#Preview {
    AppClipRootView()
        .environmentObject(AppState.shared)
}
