import Combine
import EventKit
import SwiftUI
import UIKit

// MARK: - Slot with Stats

struct SlotWithStats: Identifiable {
    let slot: SupabaseAPI.TimeSlotRow
    let availableCount: Int
    let maybeCount: Int
    let totalParticipants: Int

    var id: String { slot.id }

    var availabilityScore: Double {
        guard totalParticipants > 0 else { return 0 }
        return Double(availableCount) + Double(maybeCount) * 0.5
    }
}

// MARK: - View Model

final class PollDetailViewModel: ObservableObject {
    @Published var poll: SupabaseAPI.PollRow?
    @Published var timeSlots: [SupabaseAPI.TimeSlotRow] = []
    @Published var responses: [SupabaseAPI.ResponseRow] = []
    @Published var participants: [SupabaseAPI.ParticipantRow] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var myResponses: [String: String] = [:]  // slotId -> availability
    @Published var isSubmitting = false
    @Published var hasSubmitted = false

    // Finalization
    @Published var selectedFinalSlotId: String?
    @Published var isFinalizing = false
    @Published var showFinalizationUI = false

    let pollId: String

    var sessionId: String {
        AppState.shared.sessionId
    }

    var displayName: String {
        AppState.shared.displayNameOrDefault
    }

    var slotsByDate: [(date: String, slots: [SupabaseAPI.TimeSlotRow])] {
        let grouped = Dictionary(grouping: timeSlots) { $0.day }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, slots: $0.value) }
    }

    var participantCount: Int {
        participants.count
    }

    var isCreator: Bool {
        poll?.creatorSessionId == sessionId
    }

    var isPollOpen: Bool {
        poll?.status == "open"
    }

    var isPollFinalized: Bool {
        poll?.status == "finalized" || poll?.status == "closed"
    }

    var canFinalize: Bool {
        isCreator && isPollOpen && participantCount > 0
    }

    var finalizedSlot: SupabaseAPI.TimeSlotRow? {
        guard let slotId = poll?.finalizedSlotId else { return nil }
        return timeSlots.first { $0.id == slotId }
    }

    // Slots ranked by availability (best first)
    var slotsRankedByAvailability: [SlotWithStats] {
        timeSlots.map { slot in
            let available = responses.filter { $0.slotId == slot.id && $0.availability == "available" }.count
            let maybe = responses.filter { $0.slotId == slot.id && $0.availability == "maybe" }.count
            return SlotWithStats(
                slot: slot,
                availableCount: available,
                maybeCount: maybe,
                totalParticipants: participantCount
            )
        }.sorted { $0.availabilityScore > $1.availabilityScore }
    }

    var bestSlotId: String? {
        slotsRankedByAvailability.first?.slot.id
    }

    init(pollId: String) {
        self.pollId = pollId
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

                // Pre-select best slot for finalization
                if let best = slotsRankedByAvailability.first {
                    selectedFinalSlotId = best.slot.id
                }

            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    func toggleResponse(slotId: String) {
        // Haptic feedback
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
        isSubmitting = true
        errorMessage = nil

        let sid = sessionId
        let pid = pollId
        let name = displayName
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
                // Success haptic
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
                reloadDataSilently()
            } catch {
                errorMessage = error.localizedDescription
                // Error haptic
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
            }

            isSubmitting = false
        }
    }

    func finalizePoll(completion: @escaping (Bool) -> Void) {
        guard let slotId = selectedFinalSlotId, !isFinalizing else {
            completion(false)
            return
        }

        isFinalizing = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try await SupabaseAPI.finalizePoll(pollId: pollId, slotId: slotId)

                // Reload poll to get updated status
                if let updatedPoll = try await SupabaseAPI.fetchPoll(id: pollId) {
                    poll = updatedPoll
                }

                // Success haptic
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)

                isFinalizing = false
                completion(true)
            } catch {
                errorMessage = error.localizedDescription
                // Error haptic
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
                isFinalizing = false
                completion(false)
            }
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

                // Update best slot selection
                if let best = slotsRankedByAvailability.first {
                    selectedFinalSlotId = best.slot.id
                }
            } catch {
                // Silently fail
            }
        }
    }

    func responseCountForSlot(_ slotId: String) -> Int {
        responses.filter { $0.slotId == slotId && $0.availability == "available" }.count
    }
}

// MARK: - View

struct PollDetailView: View {
    @ObservedObject var viewModel: PollDetailViewModel
    var onDismiss: (() -> Void)?
    var onFinalize: ((FinalizedPollInfo) -> Void)?

    private let bgColor = Color(red: 0.035, green: 0.035, blue: 0.043)
    private let cardColor = Color(red: 0.063, green: 0.063, blue: 0.075)
    private let borderColor = Color(red: 0.15, green: 0.15, blue: 0.17)
    private let labelColor = Color(red: 0.63, green: 0.63, blue: 0.67)
    private let accentBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    private let dimText = Color(red: 0.4, green: 0.4, blue: 0.45)
    private let accentGreen = Color.green

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.poll == nil {
                errorView(error)
            } else if let poll = viewModel.poll {
                if viewModel.showFinalizationUI {
                    finalizationContent(poll)
                } else {
                    pollContent(poll)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bgColor.ignoresSafeArea())
        .onAppear { viewModel.loadPoll() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: accentBlue))
                .scaleEffect(1.2)
            Text("Loading poll...")
                .font(.subheadline)
                .foregroundColor(labelColor)
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
                .foregroundColor(labelColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                viewModel.loadPoll()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(accentBlue)
            .cornerRadius(10)

            if onDismiss != nil {
                Button("Done") {
                    onDismiss?()
                }
                .font(.subheadline)
                .foregroundColor(labelColor)
                .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Poll Content

    private func pollContent(_ poll: SupabaseAPI.PollRow) -> some View {
        VStack(spacing: 0) {
            // Header
            headerSection(poll)

            // Status banners
            statusBanners(poll)

            Divider().background(borderColor)

            // Instruction
            if viewModel.isPollOpen {
                Text(viewModel.hasSubmitted ? "Tap a slot to change your response" : "Tap to cycle: Yes → Maybe → No")
                    .font(.caption)
                    .foregroundColor(dimText)
                    .padding(.vertical, 8)
            }

            // Slots
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(viewModel.slotsByDate, id: \.date) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(formatDateHeader(group.date))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(labelColor)
                                .textCase(.uppercase)
                                .padding(.horizontal, 4)

                            ForEach(group.slots, id: \.id) { slot in
                                slotRow(slot, isFinalized: slot.id == poll.finalizedSlotId)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }

            // Error banner
            if let error = viewModel.errorMessage, viewModel.poll != nil {
                errorBanner(error)
            }

            // Bottom actions
            bottomActions(poll)
        }
    }

    private func headerSection(_ poll: SupabaseAPI.PollRow) -> some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.isPollFinalized ? "checkmark.seal.fill" : "calendar.badge.clock")
                .font(.title3)
                .foregroundColor(viewModel.isPollFinalized ? accentGreen : accentBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(poll.title.isEmpty ? "PlanToMeet Poll" : poll.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(viewModel.participantCount) \(viewModel.participantCount == 1 ? "participant" : "participants") · \(viewModel.timeSlots.count) time slots")
                    .font(.caption)
                    .foregroundColor(labelColor)
            }
            Spacer()

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(accentBlue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func statusBanners(_ poll: SupabaseAPI.PollRow) -> some View {
        // Finalized banner
        if let finalSlot = viewModel.finalizedSlot {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(accentGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time Selected!")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accentGreen)
                    Text("\(formatDateHeader(finalSlot.day)) at \(formatTime(finalSlot.startTime))")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(12)
            .background(accentGreen.opacity(0.15))
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

        // Creator actions (if poll is open)
        if viewModel.canFinalize {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.showFinalizationUI = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("You're the organizer")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Finalize")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accentBlue)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(accentBlue)
                }
                .padding(12)
                .background(cardColor)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
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
    private func bottomActions(_ poll: SupabaseAPI.PollRow) -> some View {
        if viewModel.isPollOpen {
            // Submit / Update button
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
                    Text(viewModel.isSubmitting
                        ? "Submitting..."
                        : (viewModel.hasSubmitted ? "Update Response" : "Submit Response"))
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.myResponses.isEmpty ? Color(red: 0.15, green: 0.15, blue: 0.18) : accentBlue)
                .cornerRadius(14)
            }
            .disabled(viewModel.isSubmitting || viewModel.myResponses.isEmpty)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(bgColor)
        }
    }

    // MARK: - Finalization Content

    private func finalizationContent(_ poll: SupabaseAPI.PollRow) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Button {
                    viewModel.showFinalizationUI = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundColor(accentBlue)
                }

                Image(systemName: "checkmark.seal")
                    .font(.title3)
                    .foregroundColor(accentGreen)
                Text("Finalize Poll")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(borderColor)

            // Instruction
            VStack(spacing: 8) {
                Text("Choose the final time for")
                    .font(.subheadline)
                    .foregroundColor(labelColor)
                Text(poll.title.isEmpty ? "your event" : "\"\(poll.title)\"")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 12)

            // Ranked slots
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.slotsRankedByAvailability.enumerated()), id: \.element.id) { index, slotStats in
                        finalizationSlotRow(slotStats, rank: index + 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }

            // Error banner
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            // Finalize button
            Button(action: {
                viewModel.finalizePoll { success in
                    if success, let slotId = viewModel.selectedFinalSlotId,
                       let slot = viewModel.timeSlots.first(where: { $0.id == slotId }),
                       let poll = viewModel.poll {
                        let info = FinalizedPollInfo(
                            pollId: poll.id,
                            title: poll.title,
                            slotId: slotId,
                            day: slot.day,
                            startTime: slot.startTime,
                            endTime: slot.endTime,
                            durationMinutes: poll.durationMinutes
                        )
                        onFinalize?(info)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if viewModel.isFinalizing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.subheadline)
                    }
                    Text(viewModel.isFinalizing ? "Finalizing..." : "Finalize & Send")
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.selectedFinalSlotId != nil && !viewModel.isFinalizing ? accentGreen : Color(red: 0.15, green: 0.15, blue: 0.18))
                .cornerRadius(14)
            }
            .disabled(viewModel.selectedFinalSlotId == nil || viewModel.isFinalizing)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(bgColor)
        }
    }

    private func finalizationSlotRow(_ slotStats: SlotWithStats, rank: Int) -> some View {
        let isSelected = viewModel.selectedFinalSlotId == slotStats.slot.id
        let isBest = rank == 1

        return Button {
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
            viewModel.selectedFinalSlotId = slotStats.slot.id
        } label: {
            HStack(spacing: 12) {
                // Rank indicator
                ZStack {
                    Circle()
                        .fill(isBest ? Color.yellow : cardColor)
                        .frame(width: 28, height: 28)
                    if isBest {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.black)
                    } else {
                        Text("\(rank)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(labelColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(formatDateHeader(slotStats.slot.day))")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    Text("\(formatTime(slotStats.slot.startTime)) - \(formatTime(slotStats.slot.endTime))")
                        .font(.caption)
                        .foregroundColor(labelColor)
                }

                Spacer()

                // Availability stats
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("\(slotStats.availableCount)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.green)
                    }
                    if slotStats.maybeCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(slotStats.maybeCount)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? accentGreen : borderColor)
            }
            .padding(12)
            .background(isSelected ? accentGreen.opacity(0.1) : cardColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentGreen.opacity(0.5) : (isBest ? Color.yellow.opacity(0.3) : borderColor), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Slot Row

    private func slotRow(_ slot: SupabaseAPI.TimeSlotRow, isFinalized: Bool) -> some View {
        let myResponse = viewModel.myResponses[slot.id]
        let yesCount = viewModel.responseCountForSlot(slot.id)

        return Button {
            if viewModel.isPollOpen {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.toggleResponse(slotId: slot.id)
            }
        } label: {
            HStack {
                if isFinalized {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.body)
                        .foregroundColor(accentGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(formatTime(slot.startTime)) - \(formatTime(slot.endTime))")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isFinalized ? accentGreen : .white)
                    if yesCount > 0 {
                        Text("\(yesCount) available")
                            .font(.caption)
                            .foregroundColor(dimText)
                    }
                }

                Spacer()

                if viewModel.isPollOpen {
                    responseIndicator(myResponse)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isFinalized ? accentGreen.opacity(0.1) : backgroundForResponse(myResponse))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFinalized ? accentGreen.opacity(0.5) : borderForResponse(myResponse), lineWidth: isFinalized ? 2 : 1)
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
                        .foregroundColor(dimText)
                    Text("No")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(dimText)
                }
            default:
                Text("Tap to vote")
                    .font(.caption)
                    .foregroundColor(dimText)
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
            return cardColor
        }
    }

    private func borderForResponse(_ response: String?) -> Color {
        switch response {
        case "available":
            return Color.green.opacity(0.25)
        case "maybe":
            return Color.orange.opacity(0.25)
        default:
            return borderColor
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
              let minute = Int(parts[1]) else { return startTime }
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return minute == 0 ? "\(h):00 \(period)" : "\(h):\(String(format: "%02d", minute)) \(period)"
    }

    var formattedShortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: day) else { return day }
        let display = DateFormatter()
        display.dateFormat = "EEE, MMM d"
        return display.string(from: date)
    }

    var eventDate: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Clean up the time string (remove any extra characters, handle HH:mm:ss format)
        let cleanTime = startTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let timeParts = cleanTime.split(separator: ":")

        // Try different formats
        let dateString = "\(day) \(cleanTime)"

        // Try HH:mm:ss first
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try HH:mm
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Fallback: manually construct the date
        if timeParts.count >= 2,
           let hour = Int(timeParts[0]),
           let minute = Int(timeParts[1]) {
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

// MARK: - Add to Calendar View

struct AddToCalendarView: View {
    let info: FinalizedPollInfo
    var onDismiss: (() -> Void)?
    var onAdded: (() -> Void)?

    @State private var isAdding = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    private let eventStore = EKEventStore()

    private let bgColor = Color(red: 0.035, green: 0.035, blue: 0.043)
    private let cardColor = Color(red: 0.063, green: 0.063, blue: 0.075)
    private let borderColor = Color(red: 0.15, green: 0.15, blue: 0.17)
    private let labelColor = Color(red: 0.63, green: 0.63, blue: 0.67)
    private let accentBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    private let accentGreen = Color.green

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Done")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(accentBlue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            // Content
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentGreen.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: showSuccess ? "checkmark" : "calendar.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(accentGreen)
                }

                // Event details
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
                        .foregroundColor(accentGreen)
                }

                if showSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(accentGreen)
                        Text("Added to your calendar!")
                            .font(.subheadline)
                            .foregroundColor(accentGreen)
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
            }
            .padding(.horizontal, 32)

            Spacer()

            // Add button
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
                    .background(accentGreen)
                    .cornerRadius(14)
                }
                .disabled(isAdding)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bgColor.ignoresSafeArea())
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
            eventStore.requestFullAccessToEvents { granted, error in
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
            eventStore.requestAccess(to: .event) { granted, error in
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
              let endDate = info.eventEndDate else {
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
            // Success haptic
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            onAdded?()
        } catch {
            isAdding = false
            errorMessage = "Failed to save event: \(error.localizedDescription)"
            // Error haptic
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
        }
    }
}
