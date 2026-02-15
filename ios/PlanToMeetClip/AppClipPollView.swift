import Combine
import EventKit
import SwiftUI
import UIKit

// MARK: - View Model

final class AppClipPollViewModel: ObservableObject {
    @Published var poll: SupabaseAPI.PollRow?
    @Published var timeSlots: [SupabaseAPI.TimeSlotRow] = []
    @Published var responses: [SupabaseAPI.ResponseRow] = []
    @Published var participants: [SupabaseAPI.ParticipantRow] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var myResponses: [String: String] = [:]  // slotId -> availability
    @Published var isSubmitting = false
    @Published var hasSubmitted = false
    @Published var displayName: String = ""

    let pollId: String

    var sessionId: String {
        AppState.shared.sessionId
    }

    var slotsByDate: [(date: String, slots: [SupabaseAPI.TimeSlotRow])] {
        let grouped = Dictionary(grouping: timeSlots) { $0.day }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, slots: $0.value) }
    }

    var participantCount: Int {
        participants.count
    }

    var isPollOpen: Bool {
        poll?.status == "open"
    }

    var isPollFinalized: Bool {
        poll?.status == "finalized" || poll?.status == "closed"
    }

    var finalizedSlot: SupabaseAPI.TimeSlotRow? {
        guard let slotId = poll?.finalizedSlotId else { return nil }
        return timeSlots.first { $0.id == slotId }
    }

    var finalizedPollInfo: FinalizedPollInfo? {
        guard let poll = poll, let slot = finalizedSlot else { return nil }
        return FinalizedPollInfo(
            pollId: poll.id,
            title: poll.title,
            slotId: slot.id,
            day: slot.day,
            startTime: slot.startTime,
            endTime: slot.endTime,
            durationMinutes: poll.durationMinutes
        )
    }

    init(pollId: String) {
        self.pollId = pollId
        self.displayName = AppState.shared.displayName
    }

    func loadPoll() {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                async let pollFetch = SupabaseAPI.fetchPoll(id: pollId)
                async let slotsFetch = SupabaseAPI.fetchTimeSlots(pollId: pollId)
                async let responsesFetch = SupabaseAPI.fetchResponses(pollId: pollId)
                async let participantsFetch = SupabaseAPI.fetchParticipants(pollId: pollId)

                let (fetchedPoll, fetchedSlots, fetchedResponses, fetchedParticipants) =
                    try await (pollFetch, slotsFetch, responsesFetch, participantsFetch)

                guard let poll = fetchedPoll else {
                    errorMessage = "Poll not found"
                    isLoading = false
                    return
                }

                self.poll = poll
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
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()

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

        // Save display name
        if !displayName.isEmpty {
            AppState.shared.updateDisplayName(displayName)
        }

        isSubmitting = true
        errorMessage = nil

        let sid = sessionId
        let pid = pollId
        let name = displayName.isEmpty ? "Anonymous" : displayName
        let responsesToSubmit = myResponses

        Task { @MainActor in
            do {
                // Insert participant if not exists
                if !participants.contains(where: { $0.sessionId == sid }) {
                    try await SupabaseAPI.insertParticipant(pollId: pid, sessionId: sid, displayName: name)
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
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
                reloadDataSilently()
            } catch {
                errorMessage = error.localizedDescription
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
            }

            isSubmitting = false
        }
    }

    private func reloadDataSilently() {
        Task { @MainActor in
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

    func responseCountForSlot(_ slotId: String) -> Int {
        responses.filter { $0.slotId == slotId && $0.availability == "available" }.count
    }
}

// MARK: - Main View

struct AppClipPollView: View {
    @StateObject private var viewModel: AppClipPollViewModel
    @State private var showCalendarSheet = false
    var onShowFullApp: () -> Void

    init(pollId: String, onShowFullApp: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AppClipPollViewModel(pollId: pollId))
        self.onShowFullApp = onShowFullApp
    }

    var body: some View {
        ZStack {
            AuthKitBackground()
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.poll == nil {
                    errorView(error)
                } else if let poll = viewModel.poll {
                    pollContent(poll)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { viewModel.loadPoll() }
        .sheet(isPresented: $showCalendarSheet) {
            if let info = viewModel.finalizedPollInfo {
                AddToCalendarSheet(info: info, isPresented: $showCalendarSheet)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentBlue))
                .scaleEffect(1.2)
            Text("Loading poll...")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Couldn't load poll")
                .font(.headline)
                .foregroundColor(.white)
            Text(error)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                viewModel.loadPoll()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Theme.accentBlue)
            .cornerRadius(10)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Poll Content

    private func pollContent(_ poll: SupabaseAPI.PollRow) -> some View {
        VStack(spacing: 0) {
            headerSection(poll)
            statusBanners()
            Divider().background(Theme.border)

            if viewModel.isPollOpen {
                nameInputSection
                instructionText
            }

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
                                slotRow(slot, isFinalized: slot.id == poll.finalizedSlotId)
                            }
                        }
                    }

                    // Get Full App banner
                    getFullAppBanner
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }

            if let error = viewModel.errorMessage, viewModel.poll != nil {
                errorBanner(error)
            }

            bottomActions()
        }
    }

    private func headerSection(_ poll: SupabaseAPI.PollRow) -> some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.isPollFinalized ? "checkmark.seal.fill" : "calendar.badge.clock")
                .font(.title3)
                .foregroundColor(viewModel.isPollFinalized ? Theme.accentGreen : Theme.accentBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(poll.title.isEmpty ? "PlanToMeet Poll" : poll.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(viewModel.participantCount) \(viewModel.participantCount == 1 ? "participant" : "participants") · \(viewModel.timeSlots.count) time slots")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .cardStyle()
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func statusBanners() -> some View {
        if let finalSlot = viewModel.finalizedSlot {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.accentGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time Selected!")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.accentGreen)
                    Text("\(formatDateHeader(finalSlot.day)) at \(formatTime(finalSlot.startTime))")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                Spacer()
                Button("Add to Calendar") {
                    showCalendarSheet = true
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.accentGreen)
            }
            .padding(12)
            .background(Theme.accentGreen.opacity(0.15))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        } else if viewModel.hasSubmitted {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("You've responded to this poll")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your name")
                .font(.caption.weight(.medium))
                .foregroundColor(Theme.textSecondary)

            TextField("Enter your name", text: $viewModel.displayName)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(12)
                .background(Theme.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .cardStyle()
        .padding(.horizontal, 16)
    }

    private var instructionText: some View {
        Text(viewModel.hasSubmitted ? "Tap a slot to change your response" : "Tap to cycle: Yes → Maybe → No")
            .font(.caption)
            .foregroundColor(Theme.textTertiary)
            .padding(.vertical, 8)
    }

    private func errorBanner(_ error: String) -> some View {
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
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.85))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func bottomActions() -> some View {
        if viewModel.isPollOpen {
            Button(action: { viewModel.submitResponses() }) {
                HStack(spacing: 8) {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: viewModel.hasSubmitted ? "arrow.triangle.2.circlepath" : "paperplane.fill")
                            .font(.subheadline)
                    }
                    Text(
                        viewModel.isSubmitting
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

    // MARK: - Slot Row

    private func slotRow(_ slot: SupabaseAPI.TimeSlotRow, isFinalized: Bool) -> some View {
        let myResponse = viewModel.myResponses[slot.id]
        let yesCount = viewModel.responseCountForSlot(slot.id)

        return Button {
            if viewModel.isPollOpen {
                viewModel.toggleResponse(slotId: slot.id)
            }
        } label: {
            HStack {
                if isFinalized {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.body)
                        .foregroundColor(Theme.accentGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(formatTime(slot.startTime)) - \(formatTime(slot.endTime))")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isFinalized ? Theme.accentGreen : .white)
                    if yesCount > 0 {
                        Text("\(yesCount) available")
                            .font(.caption)
                            .foregroundColor(Theme.textTertiary)
                    }
                }

                Spacer()

                if viewModel.isPollOpen {
                    responseIndicator(myResponse)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isFinalized ? Theme.accentGreen.opacity(0.12) : backgroundForResponse(myResponse))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isFinalized ? Theme.accentGreen.opacity(0.5) : borderForResponse(myResponse), lineWidth: isFinalized ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isPollOpen)
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
                        .foregroundColor(.orange)
                    Text("Maybe")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
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

    private func backgroundForResponse(_ response: String?) -> Color {
        switch response {
        case "available":
            return Color.green.opacity(0.08)
        case "maybe":
            return Color.orange.opacity(0.08)
        default:
            return Theme.cardBackground
        }
    }

    private func borderForResponse(_ response: String?) -> Color {
        switch response {
        case "available":
            return Color.green.opacity(0.25)
        case "maybe":
            return Color.orange.opacity(0.25)
        default:
            return Theme.border
        }
    }

    // MARK: - Get Full App Banner

    private var getFullAppBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "apps.iphone")
                    .font(.title2)
                    .foregroundColor(Theme.accentBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Get the Full App")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text("Create polls and share via iMessage")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()
            }

            Button {
                onShowFullApp()
            } label: {
                Text("Open in App Store")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accentBlue)
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .cardStyle()
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
            let minute = Int(parts[1])
        else { return timeStr }
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return minute == 0 ? "\(h) \(period)" : "\(h):\(String(format: "%02d", minute)) \(period)"
    }
}

// MARK: - Finalized Poll Info

struct FinalizedPollInfo {
    let pollId: String
    let title: String
    let slotId: String
    let day: String
    let startTime: String
    let endTime: String
    let durationMinutes: Int

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: day) else { return day }
        let display = DateFormatter()
        display.dateFormat = "EEEE, MMMM d, yyyy"
        return display.string(from: date)
    }

    var formattedTime: String {
        let parts = startTime.split(separator: ":")
        guard parts.count >= 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1])
        else { return startTime }
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return minute == 0 ? "\(h):00 \(period)" : "\(h):\(String(format: "%02d", minute)) \(period)"
    }

    var eventDate: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let cleanTime = startTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let timeParts = cleanTime.split(separator: ":")
        let dateString = "\(day) \(cleanTime)"

        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            return date
        }

        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: dateString) {
            return date
        }

        if timeParts.count >= 2,
            let hour = Int(timeParts[0]),
            let minute = Int(timeParts[1])
        {
            formatter.dateFormat = "yyyy-MM-dd"
            if let dayDate = formatter.date(from: day) {
                let calendar = Calendar.current
                return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayDate)
            }
        }

        return nil
    }

    var eventEndDate: Date? {
        guard let start = eventDate else { return nil }
        return start.addingTimeInterval(Double(durationMinutes) * 60)
    }
}

// MARK: - Add to Calendar Sheet

struct AddToCalendarSheet: View {
    let info: FinalizedPollInfo
    @Binding var isPresented: Bool

    @State private var isAdding = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    private let eventStore = EKEventStore()

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Theme.accentGreen.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: showSuccess ? "checkmark" : "calendar.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.accentGreen)
                }

                VStack(spacing: 8) {
                    Text(info.title.isEmpty ? "Event" : info.title)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(info.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Text("at \(info.formattedTime)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.accentGreen)
                }

                if showSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.accentGreen)
                        Text("Added to your calendar!")
                            .font(.subheadline)
                            .foregroundColor(Theme.accentGreen)
                    }
                    .padding(.top, 8)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                if !showSuccess {
                    Button(action: addToCalendar) {
                        HStack(spacing: 8) {
                            if isAdding {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.body)
                            }
                            Text(isAdding ? "Adding..." : "Add to Calendar")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accentGreen)
                        .cornerRadius(14)
                    }
                    .disabled(isAdding)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Theme.accentBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addToCalendar() {
        isAdding = true
        errorMessage = nil

        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized, .fullAccess:
            createEvent()
        case .notDetermined:
            requestAccess()
        default:
            isAdding = false
            errorMessage = "Calendar access denied. Go to Settings > Privacy & Security > Calendars to enable."
        }
    }

    private func requestAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        createEvent()
                    } else {
                        isAdding = false
                        errorMessage = "Calendar access was not granted."
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        createEvent()
                    } else {
                        isAdding = false
                        errorMessage = "Calendar access was not granted."
                    }
                }
            }
        }
    }

    private func createEvent() {
        guard let startDate = info.eventDate,
            let endDate = info.eventEndDate
        else {
            isAdding = false
            errorMessage = "Could not parse event date."
            return
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = info.title.isEmpty ? "PlanToMeet Event" : info.title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            isAdding = false
            showSuccess = true
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        } catch {
            isAdding = false
            errorMessage = "Failed to save event: \(error.localizedDescription)"
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
        }
    }
}

#Preview {
    AppClipPollView(pollId: "test-poll-id", onShowFullApp: {})
}
