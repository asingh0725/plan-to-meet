import Combine
import EventKit
import Messages
import SwiftUI
import UIKit

// MARK: - Poll Form ViewModel

final class PollFormViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var durationHours: Int = 1
    @Published var durationMinutesPart: Int = 0
    @Published var dateRangeStart: Date = Calendar.current.startOfDay(for: Date())
    @Published var dateRangeEnd: Date = Calendar.current.startOfDay(
        for: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    )
    @Published var isCreating: Bool = false
    @Published var createdPollId: String?
    @Published var errorMessage: String?

    // Availability grid state
    @Published var showGridPicker: Bool = false
    @Published var selectedCells: Set<String> = []

    // Calendar integration
    @Published var useCalendar: Bool = false
    @Published var calendarBusyCells: Set<String> = []

    private let eventStore = EKEventStore()

    // Use shared AppState for session management

    // MARK: - Duration

    var durationMinutes: Int {
        let total = durationHours * 60 + durationMinutesPart
        return max(15, total)
    }

    var validMinuteOptions: [Int] {
        if durationHours == 0 {
            return [15, 30, 45]
        }
        return [0, 15, 30, 45]
    }

    var formatDurationDescription: String {
        let h = durationHours
        let m = durationMinutesPart
        if h == 0 {
            return "\(m)-minute"
        } else if m == 0 {
            return h == 1 ? "1-hour" : "\(h)-hour"
        } else {
            return "\(h)h \(m)m"
        }
    }

    // MARK: - Computed Properties

    var pollURL: URL? {
        guard let id = createdPollId else { return nil }
        return URL(string: "\(AppConstants.webBaseURL)/poll/\(id)")
    }

    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && dateRangeEnd >= dateRangeStart
            && slotCount > 0
    }

    var dayCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dateRangeStart)
        let end = calendar.startOfDay(for: dateRangeEnd)
        return max(1, calendar.dateComponents([.day], from: start, to: end).day! + 1)
    }

    var slotCount: Int {
        selectedCells.count
    }

    var daysWithAvailability: Int {
        let dates = Set(selectedCells.compactMap { $0.split(separator: "|").first.map(String.init) })
        return dates.count
    }

    var pollInfo: PollMessageInfo {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let dateRange = "\(formatter.string(from: dateRangeStart)) - \(formatter.string(from: dateRangeEnd))"
        return PollMessageInfo(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: "Tap to vote on available times",
            dateRange: dateRange,
            responseCount: nil
        )
    }

    // MARK: - Duration Change

    func onDurationChanged() {
        // Ensure minutes is valid for current hours
        if durationHours == 0 && durationMinutesPart == 0 {
            durationMinutesPart = 15
        }
        selectedCells.removeAll()
    }

    func onDateRangeChanged() {
        // Remove cells that reference dates outside the new range
        let validDates = computeDateColumns()
        let validDateSet = Set(validDates)
        selectedCells = selectedCells.filter { cell in
            let dateKey = String(cell.split(separator: "|").first ?? "")
            return validDateSet.contains(dateKey)
        }
        if useCalendar {
            fetchCalendarEvents()
        }
    }

    private func computeDateColumns() -> [String] {
        var dates: [String] = []
        let calendar = Calendar.current
        var current = calendar.startOfDay(for: dateRangeStart)
        let end = calendar.startOfDay(for: dateRangeEnd)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        while current <= end {
            dates.append(formatter.string(from: current))
            current = calendar.date(byAdding: .day, value: 1, to: current)
                ?? current.addingTimeInterval(86400)
        }
        return dates
    }

    // MARK: - Session ID (uses shared AppState via App Group)

    private func getSessionId() -> String {
        return AppState.shared.sessionId
    }

    private func getDisplayName() -> String {
        return AppState.shared.displayNameOrDefault
    }

    // MARK: - Date/Time Helpers

    private func timeString(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    // MARK: - Calendar Integration

    func toggleCalendar(_ enabled: Bool) {
        if !enabled {
            useCalendar = false
            calendarBusyCells = []
            return
        }

        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized, .fullAccess:
            useCalendar = true
            fetchCalendarEvents()

        case .notDetermined:
            requestCalendarAccess()

        case .denied, .restricted:
            useCalendar = false
            errorMessage = "Calendar access was denied. Go to Settings > Privacy & Security > Calendars and enable PlanToMeet, then try again."

        case .writeOnly:
            useCalendar = false
            errorMessage = "PlanToMeet needs full calendar access. Go to Settings > Privacy & Security > Calendars > PlanToMeet and select \"Full Access\"."

        @unknown default:
            requestCalendarAccess()
        }
    }

    private func requestCalendarAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.useCalendar = true
                        self.fetchCalendarEvents()
                    } else {
                        self.useCalendar = false
                        if let error {
                            self.errorMessage = "Calendar access failed: \(error.localizedDescription)"
                        } else {
                            self.errorMessage = "Calendar access was not granted. Go to Settings > Privacy & Security > Calendars and enable PlanToMeet."
                        }
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.useCalendar = true
                        self.fetchCalendarEvents()
                    } else {
                        self.useCalendar = false
                        if let error {
                            self.errorMessage = "Calendar access failed: \(error.localizedDescription)"
                        } else {
                            self.errorMessage = "Calendar access was not granted. Go to Settings > Privacy & Security > Calendars and enable PlanToMeet."
                        }
                    }
                }
            }
        }
    }

    func fetchCalendarEvents() {
        guard useCalendar else { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dateRangeStart)
        guard let end = calendar.date(byAdding: .day, value: 1, to: dateRangeEnd) else { return }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        var busy = Set<String>()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let dur = durationMinutes
        var current = calendar.startOfDay(for: dateRangeStart)
        let endDate = calendar.startOfDay(for: dateRangeEnd)

        while current <= endDate {
            let dateKey = dateFormatter.string(from: current)
            let startMin = 6 * 60
            let endMin = 23 * 60
            var slotStart = startMin

            while slotStart + dur <= endMin {
                let hour = slotStart / 60
                let minute = slotStart % 60
                let cellStart = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: current)!
                let cellEnd = cellStart.addingTimeInterval(Double(dur) * 60)

                for event in events {
                    if cellStart < event.endDate && cellEnd > event.startDate {
                        busy.insert("\(dateKey)|\(hour)|\(minute)")
                        break
                    }
                }

                slotStart += dur
            }

            current = calendar.date(byAdding: .day, value: 1, to: current)
                ?? current.addingTimeInterval(86400)
        }

        calendarBusyCells = busy
    }

    // MARK: - Slot Generation from Selected Cells

    private func generateAvailabilityBlocks(pollId: String) -> [[String: String]] {
        let cellsByDate = Dictionary(grouping: selectedCells) { key -> String in
            String(key.split(separator: "|").first ?? "")
        }

        var blocks: [[String: String]] = []
        let dur = durationMinutes

        for (dateKey, cells) in cellsByDate {
            let times = cells.compactMap { cell -> (hour: Int, minute: Int)? in
                let parts = cell.split(separator: "|")
                guard parts.count == 3, let h = Int(parts[1]), let m = Int(parts[2]) else { return nil }
                return (hour: h, minute: m)
            }.sorted { $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute }

            guard !times.isEmpty else { continue }

            var blockStart = times[0]
            var blockEndMin = times[0].hour * 60 + times[0].minute + dur

            for i in 1..<times.count {
                let cellMin = times[i].hour * 60 + times[i].minute
                if cellMin == blockEndMin {
                    blockEndMin = cellMin + dur
                } else {
                    blocks.append([
                        "id": UUID().uuidString.lowercased(),
                        "poll_id": pollId,
                        "day": dateKey,
                        "start_time": timeString(hour: blockStart.hour, minute: blockStart.minute),
                        "end_time": timeString(hour: blockEndMin / 60, minute: blockEndMin % 60)
                    ])
                    blockStart = times[i]
                    blockEndMin = times[i].hour * 60 + times[i].minute + dur
                }
            }

            blocks.append([
                "id": UUID().uuidString.lowercased(),
                "poll_id": pollId,
                "day": dateKey,
                "start_time": timeString(hour: blockStart.hour, minute: blockStart.minute),
                "end_time": timeString(hour: blockEndMin / 60, minute: blockEndMin % 60)
            ])
        }

        return blocks
    }

    private func generateTimeSlots(pollId: String) -> [[String: String]] {
        let dur = durationMinutes
        return selectedCells.sorted().compactMap { cell -> [String: String]? in
            let parts = cell.split(separator: "|")
            guard parts.count == 3, let hour = Int(parts[1]), let minute = Int(parts[2]) else { return nil }
            let endMin = hour * 60 + minute + dur
            return [
                "id": UUID().uuidString.lowercased(),
                "poll_id": pollId,
                "day": String(parts[0]),
                "start_time": timeString(hour: hour, minute: minute),
                "end_time": timeString(hour: endMin / 60, minute: endMin % 60)
            ]
        }
    }

    // MARK: - Create Poll

    func createPoll() {
        guard isFormValid, !isCreating else { return }

        isCreating = true
        errorMessage = nil

        let pollId = UUID().uuidString.lowercased()
        let sessionId = getSessionId()
        let displayName = getDisplayName()
        let blocks = generateAvailabilityBlocks(pollId: pollId)
        let slots = generateTimeSlots(pollId: pollId)
        let pollTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let dur = durationMinutes

        Task { @MainActor in
            do {
                try await SupabaseAPI.createPoll(
                    id: pollId,
                    title: pollTitle,
                    durationMinutes: dur,
                    creatorSessionId: sessionId
                )

                try await SupabaseAPI.insertAvailabilityBlocks(pollId: pollId, blocks: blocks)
                try await SupabaseAPI.insertTimeSlots(pollId: pollId, slots: slots)
                try await SupabaseAPI.insertParticipant(
                    pollId: pollId,
                    sessionId: sessionId,
                    displayName: displayName
                )

                // Success haptic
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)

                createdPollId = pollId
            } catch {
                errorMessage = error.localizedDescription
                // Error haptic
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
            }

            isCreating = false
        }
    }
}

// MARK: - Poll Form View

struct PollFormView: View {
    @ObservedObject var viewModel: PollFormViewModel
    var onSendPoll: ((URL, PollMessageInfo) -> Void)?

    private let bgColor = Color(red: 0.035, green: 0.035, blue: 0.043)
    private let cardColor = Color(red: 0.063, green: 0.063, blue: 0.075)
    private let borderColor = Color(red: 0.15, green: 0.15, blue: 0.17)
    private let labelColor = Color(red: 0.63, green: 0.63, blue: 0.67)
    private let accentBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    private let dimText = Color(red: 0.4, green: 0.4, blue: 0.45)

    var body: some View {
        ZStack {
            if viewModel.showGridPicker {
                AvailabilityGridView(
                    dateRangeStart: viewModel.dateRangeStart,
                    dateRangeEnd: viewModel.dateRangeEnd,
                    durationMinutes: viewModel.durationMinutes,
                    initialSelection: viewModel.selectedCells,
                    calendarBusyCells: viewModel.calendarBusyCells,
                    useCalendar: viewModel.useCalendar,
                    onSave: { cells in
                        viewModel.selectedCells = cells
                        viewModel.showGridPicker = false
                    },
                    onCancel: {
                        viewModel.showGridPicker = false
                    }
                )
            } else {
                formContent
            }
        }
        .onChange(of: viewModel.createdPollId) { newId in
            guard let _ = newId, let url = viewModel.pollURL else { return }
            onSendPoll?(url, viewModel.pollInfo)
        }
    }

    private var formContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                titleSection
                durationSection
                dateRangeSection
                calendarSection
                availabilitySection
                previewSection
                errorBanner
                createButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(bgColor.ignoresSafeArea())
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundColor(accentBlue)
            Text("New Poll")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            Spacer()
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event Title")
                .font(.subheadline.weight(.medium))
                .foregroundColor(labelColor)

            TextField("e.g. Team lunch, Study session...", text: $viewModel.title)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(cardColor)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
    }

    // MARK: - Duration (Custom hours + minutes)

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.subheadline)
                    .foregroundColor(labelColor)
                Text("Duration")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(labelColor)
            }

            HStack(spacing: 12) {
                // Hours picker
                HStack(spacing: 6) {
                    Picker("", selection: $viewModel.durationHours) {
                        ForEach(0...8, id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)

                    Text("hr")
                        .font(.subheadline)
                        .foregroundColor(labelColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(cardColor)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: 1))

                // Minutes picker
                HStack(spacing: 6) {
                    Picker("", selection: $viewModel.durationMinutesPart) {
                        ForEach(viewModel.validMinuteOptions, id: \.self) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)

                    Text("min")
                        .font(.subheadline)
                        .foregroundColor(labelColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(cardColor)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: 1))

                Spacer()
            }
            .onChange(of: viewModel.durationHours) { _ in
                viewModel.onDurationChanged()
            }
            .onChange(of: viewModel.durationMinutesPart) { _ in
                viewModel.onDurationChanged()
            }

            Text("Time options in \(viewModel.formatDurationDescription) increments")
                .font(.caption)
                .foregroundColor(dimText)
        }
    }

    // MARK: - Date Range

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundColor(labelColor)
                Text("Date Range")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(labelColor)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(dimText)
                    DatePicker(
                        "",
                        selection: $viewModel.dateRangeStart,
                        in: Calendar.current.startOfDay(for: Date())...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)
                    .tint(accentBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(cardColor)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundColor(dimText)
                    DatePicker(
                        "",
                        selection: $viewModel.dateRangeEnd,
                        in: viewModel.dateRangeStart...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)
                    .tint(accentBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(cardColor)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1))
            }

            Text("\(viewModel.dayCount) \(viewModel.dayCount == 1 ? "day" : "days") selected")
                .font(.caption)
                .foregroundColor(dimText)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Calendar Toggle

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.useCalendar ? "calendar.badge.checkmark" : "calendar")
                        .font(.body)
                        .foregroundColor(accentBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use my calendar")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                        Text("Show busy times while selecting")
                            .font(.caption)
                            .foregroundColor(dimText)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.useCalendar },
                    set: { viewModel.toggleCalendar($0) }
                ))
                .labelsHidden()
                .tint(accentBlue)
            }
            .padding(14)
            .background(cardColor)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1))

            if viewModel.useCalendar {
                Text("Your calendar stays on your device. We only use it to highlight conflicts.")
                    .font(.caption)
                    .foregroundColor(dimText)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Availability (When2Meet grid button)

    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.day.timeline.left")
                    .font(.subheadline)
                    .foregroundColor(labelColor)
                Text("Your Availability")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(labelColor)
            }

            Button {
                viewModel.showGridPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.selectedCells.isEmpty
                            ? "Set availability on calendar"
                            : "\(viewModel.daysWithAvailability) \(viewModel.daysWithAvailability == 1 ? "day" : "days") with availability")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(viewModel.selectedCells.isEmpty ? .white : accentBlue)
                        Text(viewModel.selectedCells.isEmpty
                            ? "Mark when you're free on each day"
                            : "Tap to edit your availability")
                            .font(.caption)
                            .foregroundColor(dimText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(labelColor)
                }
                .padding(14)
                .background(viewModel.selectedCells.isEmpty
                    ? cardColor
                    : accentBlue.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.selectedCells.isEmpty ? borderColor : accentBlue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Options Preview")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            if viewModel.slotCount == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.body)
                        .foregroundColor(.orange)
                    Text("No time slots available yet.\nSet your availability on the calendar above.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            } else {
                HStack {
                    Text("Time options to vote on")
                        .font(.caption)
                        .foregroundColor(labelColor)
                    Spacer()
                    Text("\(viewModel.slotCount) slots")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accentBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accentBlue.opacity(0.15))
                        .cornerRadius(12)
                }
            }
        }
        .padding(14)
        .background(cardColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.2, green: 0.2, blue: 0.24), lineWidth: 1)
        )
    }

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(3)
                Spacer()
                Button {
                    viewModel.errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.red.opacity(0.85))
            .cornerRadius(12)
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button(action: { viewModel.createPoll() }) {
            HStack(spacing: 8) {
                if viewModel.isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                }
                Text(viewModel.isCreating ? "Creating..." : "Create Poll")
                    .font(.body.weight(.semibold))
            }
            .foregroundColor(viewModel.isFormValid && !viewModel.isCreating ? .white : Color(red: 0.44, green: 0.44, blue: 0.48))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.isFormValid && !viewModel.isCreating ? accentBlue : Color(red: 0.15, green: 0.15, blue: 0.18))
            .cornerRadius(16)
        }
        .disabled(!viewModel.isFormValid || viewModel.isCreating)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "questionmark.circle"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .background(Color(red: 0.063, green: 0.063, blue: 0.075))
        .cornerRadius(12)
    }
}

// MARK: - URL Validation

enum MessageURLValidator {
    static func isPollURL(_ url: URL?, baseURL: URL) -> Bool {
        guard let url else { return false }
        guard url.host == baseURL.host else { return false }

        let path = url.path
        guard path.hasPrefix("/poll/") else { return false }

        let pollId = path.replacingOccurrences(of: "/poll/", with: "")
        let trimmedId = pollId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return false }

        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        guard trimmedId.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
            return false
        }

        return true
    }

    static func extractPollId(from url: URL) -> String? {
        let path = url.path
        guard path.hasPrefix("/poll/") else { return nil }
        let pollId = path.replacingOccurrences(of: "/poll/", with: "")
        let trimmed = pollId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Data Models

struct PollMessageInfo {
    let title: String
    let subtitle: String?
    let dateRange: String?
    let responseCount: Int?
}
