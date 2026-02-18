import SwiftUI
import UIKit

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Poll Detail Screen

struct PollDetailScreen: View {
    let pollId: String
    let isReadOnly: Bool
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: PollDetailScreenViewModel
    @State private var showShareSheet = false

    init(pollId: String, isReadOnly: Bool = false) {
        self.pollId = pollId
        self.isReadOnly = isReadOnly
        _viewModel = StateObject(wrappedValue: PollDetailScreenViewModel(pollId: pollId))
    }

    var body: some View {
        ZStack {
            AuthKitBackground()

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.poll == nil {
                errorView(error)
            } else if let poll = viewModel.poll {
                pollContent(poll)
            }
        }
        .navigationTitle(viewModel.poll?.title ?? "Poll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(Theme.accentBlue)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: "\(AppConstants.webBaseURL)/poll/\(pollId)") {
                ShareSheet(items: [url])
            }
        }
        .onAppear {
            viewModel.sessionId = appState.sessionId
            viewModel.loadPoll()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentBlue))
                .scaleEffect(1.2)
            Text("Loading poll...")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Theme.accentOrange)
            Text("Couldn't load poll")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text(error)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                viewModel.loadPoll()
            }
            .secondaryButtonStyle()
        }
    }

    // MARK: - Poll Content

    private func pollContent(_ poll: SupabaseAPI.PollRow) -> some View {
        VStack(spacing: 0) {
            // Stats bar with best time
            VStack(spacing: 8) {
                HStack(spacing: 20) {
                    statItem(icon: "person.2", value: "\(viewModel.participantCount)", label: "Responded")
                    statItem(icon: "calendar", value: "\(viewModel.timeSlots.count)", label: "Time Slots")
                    if poll.status == "open" {
                        statItem(icon: "checkmark.circle", value: "Open", label: "Status", valueColor: .green)
                    } else {
                        statItem(icon: "lock", value: "Closed", label: "Status", valueColor: Theme.textTertiary)
                    }
                }

                // Best time display
                if let bestTime = viewModel.bestTimeSlot {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("Best time: \(bestTime.formattedTime)")
                            .font(.caption.weight(.medium))
                            .foregroundColor(Theme.textPrimary)
                        Text("(\(bestTime.availableCount)/\(viewModel.participantCount) available)")
                            .font(.caption)
                            .foregroundColor(Theme.accentBlue)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .cardStyle()
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Read-only banner
            if isReadOnly {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Theme.accentBlue)
                    Text("Open this poll in iMessage to vote")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.accentBlue.opacity(0.1))
            } else if viewModel.hasSubmitted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("You've responded to this poll")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider().background(Theme.border)

            // Instruction
            if !isReadOnly {
                Text(viewModel.hasSubmitted ? "Tap a slot to change your response" : "Tap to cycle: Yes → Maybe → No")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
                    .padding(.vertical, 8)
            }

            // Slots
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(viewModel.slotsByDate, id: \.date) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(formatDateHeader(group.date))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 4)

                            ForEach(group.slots, id: \.id) { slot in
                                slotRow(slot)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .padding(.bottom, isReadOnly ? 20 : 100)
            }

            // Error banner
            if let error = viewModel.errorMessage, viewModel.poll != nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        viewModel.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.red.opacity(0.85))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            // Submit button (only if not read-only)
            if !isReadOnly {
                Button(action: {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    viewModel.submitResponses()
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: viewModel.hasSubmitted ? "arrow.triangle.2.circlepath" : "paperplane.fill")
                                .font(.subheadline)
                        }
                        Text(viewModel.isSubmitting
                            ? "Submitting..."
                            : (viewModel.hasSubmitted ? "Update Response" : "Submit Response"))
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.myResponses.isEmpty ? Theme.buttonDisabledBackground : Theme.accentBlue)
                    .cornerRadius(14)
                }
                .disabled(viewModel.isSubmitting || viewModel.myResponses.isEmpty)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.background)
            }
        }
    }

    // MARK: - Stat Item

    private func statItem(icon: String, value: String, label: String, valueColor: Color = Theme.textPrimary) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(valueColor)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Slot Row

    private func slotRow(_ slot: SupabaseAPI.TimeSlotRow) -> some View {
        let myResponse = viewModel.myResponses[slot.id]
        let yesCount = viewModel.responseCountForSlot(slot.id, type: "available")
        let maybeCount = viewModel.responseCountForSlot(slot.id, type: "maybe")
        let isBestSlot = viewModel.bestTimeSlot?.slotId == slot.id

        return Group {
            if isReadOnly {
                // Read-only: just display
                slotContent(slot: slot, myResponse: myResponse, yesCount: yesCount, maybeCount: maybeCount, isBestSlot: isBestSlot)
            } else {
                // Interactive: allow voting
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.toggleResponse(slotId: slot.id)
                } label: {
                    slotContent(slot: slot, myResponse: myResponse, yesCount: yesCount, maybeCount: maybeCount, isBestSlot: isBestSlot)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func slotContent(slot: SupabaseAPI.TimeSlotRow, myResponse: String?, yesCount: Int, maybeCount: Int, isBestSlot: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isBestSlot {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                    Text("\(formatTime(slot.startTime)) - \(formatTime(slot.endTime))")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                }

                HStack(spacing: 8) {
                    if yesCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("\(yesCount)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    if maybeCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(Theme.accentOrange)
                            Text("\(maybeCount)")
                                .font(.caption)
                                .foregroundColor(Theme.accentOrange)
                        }
                    }
                    if yesCount == 0 && maybeCount == 0 {
                        Text("No responses yet")
                            .font(.caption)
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }

            Spacer()

            if !isReadOnly {
                responseIndicator(myResponse)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundForResponse(myResponse, isBest: isBestSlot))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderForResponse(myResponse, isBest: isBestSlot), lineWidth: 1)
        )
    }

    private func responseIndicator(_ response: String?) -> some View {
        Group {
            switch response {
            case "available":
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Yes")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                }
            case "maybe":
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(Theme.accentOrange)
                    Text("Maybe")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.accentOrange)
                }
            case "unavailable":
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textTertiary)
                    Text("No")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.textTertiary)
                }
            default:
                Text("Tap to vote")
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    private func backgroundForResponse(_ response: String?, isBest: Bool) -> Color {
        if isBest { return Color.yellow.opacity(0.08) }
        switch response {
        case "available":
            return Color.green.opacity(0.08)
        case "maybe":
            return Color.orange.opacity(0.08)
        default:
            return Theme.cardBackground
        }
    }

    private func borderForResponse(_ response: String?, isBest: Bool) -> Color {
        if isBest { return Color.yellow.opacity(0.3) }
        switch response {
        case "available":
            return Color.green.opacity(0.25)
        case "maybe":
            return Color.orange.opacity(0.25)
        default:
            return Theme.border
        }
    }

    // MARK: - Formatting

    private func formatDateHeader(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let display = DateFormatter()
        display.dateFormat = "EEEE, MMM d"
        return display.string(from: date)
    }

    private func formatTime(_ timeStr: String) -> String {
        let parts = timeStr.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return timeStr }
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return minute == 0 ? "\(h) \(period)" : "\(h):\(String(format: "%02d", minute)) \(period)"
    }
}

// MARK: - Best Time Info

struct BestTimeSlotInfo {
    let slotId: String
    let day: String
    let startTime: String
    let endTime: String
    let availableCount: Int

    var formattedTime: String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "EEE, MMM d"

        var dayDisplay = day
        if let date = dayFormatter.date(from: day) {
            dayDisplay = displayFormatter.string(from: date)
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let displayTimeFormatter = DateFormatter()
        displayTimeFormatter.dateFormat = "h:mm a"

        var startDisplay = startTime
        if let time = timeFormatter.date(from: startTime) {
            startDisplay = displayTimeFormatter.string(from: time)
        }

        return "\(dayDisplay) at \(startDisplay)"
    }
}

// MARK: - View Model

@MainActor
final class PollDetailScreenViewModel: ObservableObject {
    @Published var poll: SupabaseAPI.PollRow?
    @Published var timeSlots: [SupabaseAPI.TimeSlotRow] = []
    @Published var responses: [SupabaseAPI.ResponseRow] = []
    @Published var participants: [SupabaseAPI.ParticipantRow] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var myResponses: [String: String] = [:]
    @Published var isSubmitting = false
    @Published var hasSubmitted = false

    let pollId: String
    var sessionId: String = ""

    var slotsByDate: [(date: String, slots: [SupabaseAPI.TimeSlotRow])] {
        let grouped = Dictionary(grouping: timeSlots) { $0.day }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, slots: $0.value) }
    }

    var participantCount: Int {
        participants.count
    }

    var bestTimeSlot: BestTimeSlotInfo? {
        guard !timeSlots.isEmpty else { return nil }

        // Count "available" responses per slot
        var slotAvailability: [String: Int] = [:]
        for response in responses {
            if response.availability == "available" {
                slotAvailability[response.slotId, default: 0] += 1
            }
        }

        // Find slot with most availability
        guard let bestSlotId = slotAvailability.max(by: { $0.value < $1.value })?.key,
              let bestSlot = timeSlots.first(where: { $0.id == bestSlotId }),
              let availableCount = slotAvailability[bestSlotId],
              availableCount > 0 else {
            return nil
        }

        return BestTimeSlotInfo(
            slotId: bestSlot.id,
            day: bestSlot.day,
            startTime: bestSlot.startTime,
            endTime: bestSlot.endTime,
            availableCount: availableCount
        )
    }

    init(pollId: String) {
        self.pollId = pollId
    }

    func loadPoll() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                async let pollFetch = SupabaseAPI.fetchPoll(id: pollId)
                async let slotsFetch = SupabaseAPI.fetchTimeSlots(pollId: pollId)
                async let responsesFetch = SupabaseAPI.fetchResponses(pollId: pollId)
                async let participantsFetch = SupabaseAPI.fetchParticipants(pollId: pollId)

                let (fetchedPoll, fetchedSlots, fetchedResponses, fetchedParticipants) =
                    try await (pollFetch, slotsFetch, responsesFetch, participantsFetch)

                poll = fetchedPoll
                timeSlots = fetchedSlots
                responses = fetchedResponses
                participants = fetchedParticipants

                // Load existing responses for this session
                let myExisting = fetchedResponses.filter { $0.sessionId == sessionId }
                for resp in myExisting {
                    myResponses[resp.slotId] = resp.availability
                }
                hasSubmitted = !myExisting.isEmpty

            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    func toggleResponse(slotId: String) {
        let current = myResponses[slotId]
        switch current {
        case nil, "unavailable":
            myResponses[slotId] = "available"
        case "available":
            myResponses[slotId] = "maybe"
        case "maybe":
            myResponses[slotId] = "unavailable"
        default:
            myResponses[slotId] = "available"
        }
    }

    func submitResponses() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        let sid = sessionId
        let pid = pollId
        let responsesToSubmit = myResponses
        let displayName = AppState.shared.displayNameOrDefault

        Task {
            do {
                // Insert participant if not exists
                if !participants.contains(where: { $0.sessionId == sid }) {
                    try await SupabaseAPI.insertParticipant(pollId: pid, sessionId: sid, displayName: displayName)
                }

                // Submit each response
                for (slotId, availability) in responsesToSubmit {
                    try await SupabaseAPI.submitResponse(
                        pollId: pid,
                        slotId: slotId,
                        sessionId: sid,
                        availability: availability
                    )
                }

                hasSubmitted = true
                reloadDataSilently()
            } catch {
                errorMessage = error.localizedDescription
            }

            isSubmitting = false
        }
    }

    private func reloadDataSilently() {
        Task {
            do {
                async let responsesFetch = SupabaseAPI.fetchResponses(pollId: pollId)
                async let participantsFetch = SupabaseAPI.fetchParticipants(pollId: pollId)

                let (fetchedResponses, fetchedParticipants) =
                    try await (responsesFetch, participantsFetch)

                responses = fetchedResponses
                participants = fetchedParticipants
            } catch {
                // Silently fail
            }
        }
    }

    func responseCountForSlot(_ slotId: String, type: String = "available") -> Int {
        responses.filter { $0.slotId == slotId && $0.availability == type }.count
    }
}

#Preview {
    NavigationStack {
        PollDetailScreen(pollId: "test-poll-id", isReadOnly: true)
            .environmentObject(AppState.shared)
    }
}
