import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var showCreatePoll = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuthKitBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        createInMessagesCard

                        if viewModel.isLoading {
                            loadingView
                        } else if viewModel.myPolls.isEmpty && viewModel.respondedPolls.isEmpty {
                            emptyStateView
                        } else {
                            pollSections
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("PlanToMeet")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showCreatePoll = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.accentBlue)
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Create new poll")
                }
            }
            .refreshable {
                await viewModel.loadPolls(sessionId: appState.sessionId)
            }
            .navigationDestination(for: SupabaseAPI.PollRow.self) { poll in
                PollDetailScreen(pollId: poll.id, isReadOnly: true)
            }
            .sheet(isPresented: $showCreatePoll) {
                Task { await viewModel.loadPolls(sessionId: appState.sessionId) }
            } content: {
                CreatePollView()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadPolls(sessionId: appState.sessionId)
            }
        }
    }

    // MARK: - Create in Messages Card

    private var createInMessagesCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Polls in iMessage")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)

                    Text("Open the PlanToMeet app in any iMessage conversation to create and share polls.")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(Theme.accentBlue)
                Text("Polls shared via iMessage give everyone the best experience")
                    .font(.caption2)
                    .foregroundColor(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                .stroke(Theme.accentBlue.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentBlue))
            Text("Loading polls...")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(Theme.textTertiary)

            Text("No Polls Yet")
                .font(.title3.weight(.semibold))
                .foregroundColor(Theme.textPrimary)

            Text("Create your first poll in iMessage to get started. Open any conversation, tap the Apps button, and select PlanToMeet.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // How-to steps
            VStack(alignment: .leading, spacing: 12) {
                howToStep(number: 1, text: "Open iMessage conversation")
                howToStep(number: 2, text: "Tap the + or Apps button")
                howToStep(number: 3, text: "Select PlanToMeet")
                howToStep(number: 4, text: "Create and send your poll")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func howToStep(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Theme.accentBlue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Poll Sections

    private var pollSections: some View {
        VStack(spacing: 24) {
            if !viewModel.myPolls.isEmpty {
                pollSection(title: "My Polls", icon: "person.crop.circle", polls: viewModel.myPolls)
            }

            if !viewModel.respondedPolls.isEmpty {
                pollSection(title: "Responded", icon: "checkmark.circle", polls: viewModel.respondedPolls)
            }
        }
    }

    private func pollSection(title: String, icon: String, polls: [PollWithStats]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("\(polls.count)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.elevatedBackground)
                    .cornerRadius(8)
            }
            .padding(.leading, 4)

            VStack(spacing: 10) {
                ForEach(polls) { pollWithStats in
                    PollCard(pollWithStats: pollWithStats)
                }
            }
        }
    }
}

// MARK: - Poll With Stats

struct PollWithStats: Identifiable {
    let poll: SupabaseAPI.PollRow
    let participantCount: Int
    let bestTimeSlot: BestTimeInfo?

    var id: String { poll.id }
}

struct BestTimeInfo {
    let day: String
    let startTime: String
    let endTime: String
    let availableCount: Int
    let totalParticipants: Int

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

        // Convert time
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

// MARK: - Poll Card

struct PollCard: View {
    let pollWithStats: PollWithStats

    private var poll: SupabaseAPI.PollRow { pollWithStats.poll }

    var body: some View {
        NavigationLink(value: poll) {
            VStack(alignment: .leading, spacing: 12) {
                // Title and status
                HStack {
                    Text(poll.title)
                        .font(.body.weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    statusBadge
                }

                // Best time (if available)
                if let bestTime = pollWithStats.bestTimeSlot {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("Best: \(bestTime.formattedTime)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("(\(bestTime.availableCount)/\(bestTime.totalParticipants))")
                            .font(.caption)
                            .foregroundColor(Theme.accentBlue)
                    }
                }

                // Stats row
                HStack(spacing: 16) {
                    statItem(icon: "person.2", value: "\(pollWithStats.participantCount) responded")

                    statItem(icon: "clock", value: "\(poll.durationMinutes) min")

                    Spacer()

                    if let date = poll.createdDate {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        let isOpen = poll.status == "open"
        let isFinalized = poll.status == "finalized"

        return HStack(spacing: 4) {
            if isFinalized {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
            }
            Text(isOpen ? "Open" : (isFinalized ? "Finalized" : "Closed"))
        }
        .font(.caption2.weight(.medium))
        .foregroundColor(isOpen ? .green : (isFinalized ? Theme.accentBlue : Theme.textTertiary))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isOpen ? Color.green.opacity(0.15) : (isFinalized ? Theme.accentBlue.opacity(0.15) : Theme.elevatedBackground))
        .cornerRadius(6)
    }

    private func statItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - View Model

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var myPolls: [PollWithStats] = []
    @Published var respondedPolls: [PollWithStats] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadPolls(sessionId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            async let createdFetch = SupabaseAPI.fetchPollsCreatedBy(sessionId: sessionId)
            async let respondedFetch = SupabaseAPI.fetchPollsRespondedToBy(sessionId: sessionId)

            let (created, responded) = try await (createdFetch, respondedFetch)

            // Load stats for each poll
            myPolls = await loadPollStats(for: created)

            // Filter out polls that are in myPolls
            let myPollIds = Set(created.map { $0.id })
            let filteredResponded = responded.filter { !myPollIds.contains($0.id) }
            respondedPolls = await loadPollStats(for: filteredResponded)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadPollStats(for polls: [SupabaseAPI.PollRow]) async -> [PollWithStats] {
        var results: [PollWithStats] = []

        for poll in polls {
            do {
                async let participantsFetch = SupabaseAPI.fetchParticipants(pollId: poll.id)
                async let responsesFetch = SupabaseAPI.fetchResponses(pollId: poll.id)
                async let slotsFetch = SupabaseAPI.fetchTimeSlots(pollId: poll.id)

                let (participants, responses, slots) = try await (participantsFetch, responsesFetch, slotsFetch)

                let bestTime = calculateBestTime(slots: slots, responses: responses, totalParticipants: participants.count)

                results.append(PollWithStats(
                    poll: poll,
                    participantCount: participants.count,
                    bestTimeSlot: bestTime
                ))
            } catch {
                // If we can't load stats, still show the poll with 0 count
                results.append(PollWithStats(poll: poll, participantCount: 0, bestTimeSlot: nil))
            }
        }

        return results
    }

    private func calculateBestTime(slots: [SupabaseAPI.TimeSlotRow], responses: [SupabaseAPI.ResponseRow], totalParticipants: Int) -> BestTimeInfo? {
        guard totalParticipants > 0, !slots.isEmpty else { return nil }

        // Count "available" responses per slot
        var slotAvailability: [String: Int] = [:]
        for response in responses {
            if response.availability == "available" {
                slotAvailability[response.slotId, default: 0] += 1
            }
        }

        // Find slot with most availability
        guard let bestSlotId = slotAvailability.max(by: { $0.value < $1.value })?.key,
              let bestSlot = slots.first(where: { $0.id == bestSlotId }),
              let availableCount = slotAvailability[bestSlotId],
              availableCount > 0 else {
            return nil
        }

        return BestTimeInfo(
            day: bestSlot.day,
            startTime: bestSlot.startTime,
            endTime: bestSlot.endTime,
            availableCount: availableCount,
            totalParticipants: totalParticipants
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState.shared)
        .preferredColorScheme(.dark)
}
