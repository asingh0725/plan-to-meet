import EventKit
import SwiftUI
import UIKit

// MARK: - Create Poll View Model

@MainActor
final class CreatePollViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var durationHours: Int = 1
    @Published var durationMinutesPart: Int = 0
    @Published var dateRangeStart: Date = Calendar.current.startOfDay(for: Date())
    @Published var dateRangeEnd: Date = Calendar.current.startOfDay(
        for: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    )
    @Published var showGridPicker: Bool = false
    @Published var selectedCells: Set<String> = []
    @Published var calendarBusyCells: Set<String> = []
    @Published var useCalendar: Bool = false
    @Published var isCreating: Bool = false
    @Published var createdPollId: String?
    @Published var errorMessage: String?

    private let eventStore = EKEventStore()

    var durationMinutes: Int { max(15, durationHours * 60 + durationMinutesPart) }

    var validMinuteOptions: [Int] { durationHours == 0 ? [15, 30, 45] : [0, 15, 30, 45] }

    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && dateRangeEnd >= dateRangeStart
            && !selectedCells.isEmpty
    }

    var slotCount: Int { selectedCells.count }

    var dayCount: Int {
        let c = Calendar.current
        return max(1, c.dateComponents([.day], from: c.startOfDay(for: dateRangeStart),
                                       to: c.startOfDay(for: dateRangeEnd)).day! + 1)
    }

    var daysWithAvailability: Int {
        Set(selectedCells.compactMap { $0.split(separator: "|").first.map(String.init) }).count
    }

    var pollURL: URL? {
        guard let id = createdPollId else { return nil }
        return URL(string: "\(AppConstants.webBaseURL)/poll/\(id)")
    }

    func onDurationChanged() {
        if durationHours == 0 && durationMinutesPart == 0 { durationMinutesPart = 15 }
        selectedCells.removeAll()
    }

    func onDateRangeChanged() {
        let validDates = Set(computeDateColumns())
        selectedCells = selectedCells.filter { validDates.contains(String($0.split(separator: "|").first ?? "")) }
        if useCalendar { fetchCalendarEvents() }
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
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86400)
        }
        return dates
    }

    // MARK: - Calendar

    func toggleCalendar(_ enabled: Bool) {
        guard enabled else { useCalendar = false; calendarBusyCells = []; return }
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            useCalendar = true; fetchCalendarEvents()
        case .notDetermined:
            requestCalendarAccess()
        default:
            errorMessage = "Calendar access denied. Enable in Settings → Privacy → Calendars."
        }
    }

    private func requestCalendarAccess() {
        let handle: (Bool, Error?) -> Void = { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted { self.useCalendar = true; self.fetchCalendarEvents() }
                else { self.errorMessage = "Calendar access not granted." }
            }
        }
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents(completion: handle)
        } else {
            eventStore.requestAccess(to: .event, completion: handle)
        }
    }

    func fetchCalendarEvents() {
        guard useCalendar else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dateRangeStart)
        guard let end = calendar.date(byAdding: .day, value: 1, to: dateRangeEnd) else { return }
        let events = eventStore.events(matching: eventStore.predicateForEvents(withStart: start, end: end, calendars: nil))

        var busy = Set<String>()
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; df.locale = Locale(identifier: "en_US_POSIX")
        let dur = durationMinutes
        var current = calendar.startOfDay(for: dateRangeStart)
        let endDate = calendar.startOfDay(for: dateRangeEnd)
        while current <= endDate {
            let dateKey = df.string(from: current)
            var slotStart = 0
            while slotStart + dur <= 24 * 60 {
                let hour = slotStart / 60; let minute = slotStart % 60
                let cellStart = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: current)!
                let cellEnd = cellStart.addingTimeInterval(Double(dur) * 60)
                if events.contains(where: { cellStart < $0.endDate && cellEnd > $0.startDate }) {
                    busy.insert("\(dateKey)|\(hour)|\(minute)")
                }
                slotStart += dur
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86400)
        }
        calendarBusyCells = busy
    }

    // MARK: - Slot Generation

    private func timeString(_ hour: Int, _ minute: Int) -> String { String(format: "%02d:%02d", hour, minute) }

    private func generateSlots(pollId: String) -> [[String: String]] {
        let dur = durationMinutes
        return selectedCells.sorted().compactMap { cell -> [String: String]? in
            let parts = cell.split(separator: "|")
            guard parts.count == 3, let h = Int(parts[1]), let m = Int(parts[2]) else { return nil }
            let endMin = h * 60 + m + dur
            return ["id": UUID().uuidString.lowercased(), "poll_id": pollId,
                    "day": String(parts[0]), "start_time": timeString(h, m),
                    "end_time": timeString(endMin / 60, endMin % 60)]
        }
    }

    private func generateBlocks(pollId: String) -> [[String: String]] {
        let cellsByDate = Dictionary(grouping: selectedCells) { String($0.split(separator: "|").first ?? "") }
        var blocks: [[String: String]] = []
        let dur = durationMinutes
        for (dateKey, cells) in cellsByDate {
            let times = cells.compactMap { cell -> (hour: Int, minute: Int)? in
                let parts = cell.split(separator: "|")
                guard parts.count == 3, let h = Int(parts[1]), let m = Int(parts[2]) else { return nil }
                return (h, m)
            }.sorted { $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute }
            guard !times.isEmpty else { continue }
            var blockStart = times[0], blockEndMin = times[0].hour * 60 + times[0].minute + dur
            for i in 1..<times.count {
                let cellMin = times[i].hour * 60 + times[i].minute
                if cellMin == blockEndMin { blockEndMin = cellMin + dur }
                else {
                    blocks.append(["id": UUID().uuidString.lowercased(), "poll_id": pollId,
                                   "day": dateKey, "start_time": timeString(blockStart.hour, blockStart.minute),
                                   "end_time": timeString(blockEndMin / 60, blockEndMin % 60)])
                    blockStart = times[i]; blockEndMin = cellMin + dur
                }
            }
            blocks.append(["id": UUID().uuidString.lowercased(), "poll_id": pollId,
                           "day": dateKey, "start_time": timeString(blockStart.hour, blockStart.minute),
                           "end_time": timeString(blockEndMin / 60, blockEndMin % 60)])
        }
        return blocks
    }

    // MARK: - Create Poll

    func createPoll() {
        guard isFormValid, !isCreating else { return }
        isCreating = true; errorMessage = nil
        let pollId = UUID().uuidString.lowercased()
        let sessionId = AppState.shared.sessionId
        let displayName = AppState.shared.displayNameOrDefault
        let slots = generateSlots(pollId: pollId)
        let blocks = generateBlocks(pollId: pollId)
        let pollTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let dur = durationMinutes
        Task {
            do {
                try await SupabaseAPI.createPoll(id: pollId, title: pollTitle, durationMinutes: dur, creatorSessionId: sessionId)
                try await SupabaseAPI.insertAvailabilityBlocks(pollId: pollId, blocks: blocks)
                try await SupabaseAPI.insertTimeSlots(pollId: pollId, slots: slots)
                try await SupabaseAPI.insertParticipant(pollId: pollId, sessionId: sessionId, displayName: displayName)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                createdPollId = pollId
            } catch {
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            isCreating = false
        }
    }
}

// MARK: - Create Poll View

struct CreatePollView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreatePollViewModel()
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AuthKitBackground()

                if viewModel.showGridPicker {
                    AvailabilityGridView(
                        dateRangeStart: viewModel.dateRangeStart,
                        dateRangeEnd: viewModel.dateRangeEnd,
                        durationMinutes: viewModel.durationMinutes,
                        initialSelection: viewModel.selectedCells,
                        calendarBusyCells: viewModel.calendarBusyCells,
                        useCalendar: viewModel.useCalendar,
                        onSave: { viewModel.selectedCells = $0; viewModel.showGridPicker = false },
                        onCancel: { viewModel.showGridPicker = false }
                    )
                } else {
                    formContent
                }
            }
            .navigationTitle("New Poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.accentBlue)
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: { dismiss() }) {
                if let url = viewModel.pollURL {
                    ShareSheet(items: [url])
                }
            }
            .onChange(of: viewModel.createdPollId) { newId in
                if newId != nil { showShareSheet = true }
            }
        }
    }

    // MARK: - Form Content

    private var formContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                titleSection
                durationSection
                dateRangeSection
                calendarSection
                availabilitySection
                slotPreview

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                createButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event Title")
                .font(.subheadline.weight(.medium))
                .foregroundColor(Theme.textSecondary)

            TextField("e.g. Team lunch, Study session...", text: $viewModel.title)
                .font(.body)
                .foregroundColor(Theme.textPrimary)
                .padding(14)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadiusMedium)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium).stroke(Theme.border, lineWidth: 1))
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Duration", systemImage: "clock")
                .font(.subheadline.weight(.medium))
                .foregroundColor(Theme.textSecondary)

            HStack(spacing: 12) {
                durationPicker(label: "hr", values: Array(0...8), selection: $viewModel.durationHours)
                durationPicker(label: "min", values: viewModel.validMinuteOptions, selection: $viewModel.durationMinutesPart)
                Spacer()
            }
            .onChange(of: viewModel.durationHours) { _ in viewModel.onDurationChanged() }
            .onChange(of: viewModel.durationMinutesPart) { _ in viewModel.onDurationChanged() }

            Text("Slots in \(viewModel.durationHours == 0 ? "" : "\(viewModel.durationHours)h ")\(viewModel.durationMinutesPart == 0 && viewModel.durationHours > 0 ? "" : "\(viewModel.durationMinutesPart)min") increments")
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
        }
    }

    private func durationPicker(label: String, values: [Int], selection: Binding<Int>) -> some View {
        HStack(spacing: 6) {
            Picker("", selection: selection) {
                ForEach(values, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Theme.textPrimary)
            Text(label).font(.subheadline).foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.cardBackground)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Date Range

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Date Range", systemImage: "calendar")
                .font(.subheadline.weight(.medium))
                .foregroundColor(Theme.textSecondary)

            HStack(spacing: 10) {
                dateButton(label: "From", date: viewModel.dateRangeStart, isPresented: $showStartDatePicker,
                           range: Calendar.current.startOfDay(for: Date())..., binding: $viewModel.dateRangeStart)
                dateButton(label: "To", date: viewModel.dateRangeEnd, isPresented: $showEndDatePicker,
                           range: viewModel.dateRangeStart..., binding: $viewModel.dateRangeEnd)
            }
            .onChange(of: viewModel.dateRangeStart) { _ in viewModel.onDateRangeChanged() }
            .onChange(of: viewModel.dateRangeEnd) { _ in viewModel.onDateRangeChanged() }

            Text("\(viewModel.dayCount) \(viewModel.dayCount == 1 ? "day" : "days") selected")
                .font(.caption).foregroundColor(Theme.textTertiary)
        }
    }

    private func dateButton(label: String, date: Date, isPresented: Binding<Bool>, range: PartialRangeFrom<Date>, binding: Binding<Date>) -> some View {
        let formatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f }()
        return Button { isPresented.wrappedValue = true } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption).foregroundColor(Theme.textTertiary)
                Text(formatter.string(from: date)).font(.subheadline.weight(.medium)).foregroundColor(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: isPresented) {
            DatePickerSheetView(title: label, selection: binding, range: range, onDismiss: { isPresented.wrappedValue = false })
                .presentationDetents([.medium]).presentationDragIndicator(.visible)
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Use my calendar", systemImage: viewModel.useCalendar ? "calendar.badge.checkmark" : "calendar")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(get: { viewModel.useCalendar }, set: { viewModel.toggleCalendar($0) }))
                    .labelsHidden().tint(Theme.accentBlue)
            }
            .padding(14)
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

            if viewModel.useCalendar {
                Text("Your calendar stays on your device. Only used to highlight conflicts.")
                    .font(.caption).foregroundColor(Theme.textTertiary).padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Availability Grid Button

    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your Availability", systemImage: "calendar.day.timeline.left")
                .font(.subheadline.weight(.medium)).foregroundColor(Theme.textSecondary)

            Button { viewModel.showGridPicker = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.selectedCells.isEmpty ? "Set availability" : "\(viewModel.daysWithAvailability) day\(viewModel.daysWithAvailability == 1 ? "" : "s") with availability")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(viewModel.selectedCells.isEmpty ? Theme.textPrimary : Theme.accentBlue)
                        Text(viewModel.selectedCells.isEmpty ? "Mark when you're free each day" : "Tap to edit")
                            .font(.caption).foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(Theme.textSecondary)
                }
                .padding(14)
                .background(viewModel.selectedCells.isEmpty ? Theme.cardBackground : Theme.accentBlue.opacity(0.08))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(viewModel.selectedCells.isEmpty ? Theme.border : Theme.accentBlue.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Slot Preview

    private var slotPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.subheadline.weight(.semibold)).foregroundColor(Theme.textPrimary)

            if viewModel.slotCount == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                    Text("No slots yet — set your availability above")
                        .font(.caption).foregroundColor(.orange)
                }
            } else {
                HStack {
                    Text("Time slots to vote on").font(.caption).foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(viewModel.slotCount) slots")
                        .font(.caption.weight(.semibold)).foregroundColor(Theme.accentBlue)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.accentBlue.opacity(0.15)).cornerRadius(12)
                }
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.white)
            Text(error).font(.caption).foregroundColor(.white).lineLimit(3)
            Spacer()
            Button { viewModel.errorMessage = nil } label: {
                Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.7))
            }.buttonStyle(.plain)
        }
        .padding(12).background(Color.red.opacity(0.85)).cornerRadius(12)
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            viewModel.createPoll()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isCreating {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark").font(.body.weight(.semibold))
                }
                Text(viewModel.isCreating ? "Creating..." : "Create Poll").font(.body.weight(.semibold))
            }
            .primaryButtonStyle(isEnabled: viewModel.isFormValid && !viewModel.isCreating)
        }
        .disabled(!viewModel.isFormValid || viewModel.isCreating)
    }
}

// MARK: - Date Picker Sheet (main app version)

private struct DatePickerSheetView: View {
    let title: String
    @Binding var selection: Date
    let range: PartialRangeFrom<Date>
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                DatePicker("", selection: $selection, in: range, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Theme.accentBlue)
                    .colorScheme(.dark)
                    .padding()
                Spacer()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }.foregroundColor(Theme.accentBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    CreatePollView()
        .environmentObject(AppState.shared)
}
