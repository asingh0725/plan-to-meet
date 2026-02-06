import SwiftUI
import UIKit

// MARK: - Time Slot Model

struct TimeSlot: Identifiable, Hashable {
    let startMinutes: Int
    let durationMinutes: Int

    var id: Int { startMinutes }
    var hour: Int { startMinutes / 60 }
    var minute: Int { startMinutes % 60 }
    var endMinutes: Int { startMinutes + durationMinutes }

    var startLabel: String {
        let h = hour
        let m = minute
        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        if m == 0 {
            return "\(displayHour) \(period)"
        }
        return "\(displayHour):\(String(format: "%02d", m)) \(period)"
    }
}

// MARK: - View

struct AvailabilityGridView: View {
    let dateRangeStart: Date
    let dateRangeEnd: Date
    let durationMinutes: Int
    let initialSelection: Set<String>
    let calendarBusyCells: Set<String>
    let useCalendar: Bool
    let onSave: (Set<String>) -> Void
    let onCancel: () -> Void

    @State private var selectedCells: Set<String> = []

    private let cellHeight: CGFloat = 44
    private let timeLabelWidth: CGFloat = 48
    private let minColumnWidth: CGFloat = 56
    private let dateHeaderHeight: CGFloat = 50

    private let bgColor = Color(red: 0.035, green: 0.035, blue: 0.043)
    private let accentBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    private let borderColor = Color(red: 0.15, green: 0.15, blue: 0.17)
    private let dimText = Color(red: 0.4, green: 0.4, blue: 0.45)
    private let labelColor = Color(red: 0.63, green: 0.63, blue: 0.67)

    // MARK: - Computed Data

    private var dateColumns: [String] {
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

    private var timeSlots: [TimeSlot] {
        var slots: [TimeSlot] = []
        let startMin = 6 * 60    // 6 AM
        let endMin = 23 * 60     // 11 PM
        var current = startMin
        while current + durationMinutes <= endMin {
            slots.append(TimeSlot(startMinutes: current, durationMinutes: durationMinutes))
            current += durationMinutes
        }
        return slots
    }

    private var conflictCount: Int {
        guard useCalendar else { return 0 }
        return selectedCells.intersection(calendarBusyCells).count
    }

    private func columnWidth(for totalWidth: CGFloat) -> CGFloat {
        let available = totalWidth - timeLabelWidth
        let natural = available / CGFloat(dateColumns.count)
        return max(minColumnWidth, natural)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().background(borderColor)

            helperText

            GeometryReader { geo in
                gridContent(totalWidth: geo.size.width)
            }

            footer
        }
        .background(bgColor.ignoresSafeArea())
        .onAppear {
            selectedCells = initialSelection
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundColor(labelColor)
                    .frame(width: 36, height: 36)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.18))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Set Availability")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
                onSave(selectedCells)
            }) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(accentBlue)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helper Text

    private var helperText: some View {
        VStack(spacing: 6) {
            Text("Tap cells to mark when you're available")
                .font(.caption)
                .foregroundColor(labelColor)

            if useCalendar {
                HStack(spacing: 16) {
                    legendItem(color: Color(red: 0.25, green: 0.25, blue: 0.3), label: "Busy")
                    legendItem(color: accentBlue.opacity(0.6), label: "Selected")
                    legendItem(color: Color.orange.opacity(0.7), label: "Conflict")
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Grid

    private func gridContent(totalWidth: CGFloat) -> some View {
        let colWidth = columnWidth(for: totalWidth)
        let gridWidth = colWidth * CGFloat(dateColumns.count)
        let availableForGrid = totalWidth - timeLabelWidth
        let needsHorizontalScroll = gridWidth > availableForGrid + 1

        return ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                // Time labels column
                VStack(spacing: 0) {
                    Color.clear.frame(height: dateHeaderHeight + 1)

                    ForEach(timeSlots) { slot in
                        Text(slot.startLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(dimText)
                            .frame(width: timeLabelWidth, height: cellHeight, alignment: .trailing)
                            .padding(.trailing, 3)
                    }
                }
                .frame(width: timeLabelWidth)

                // Grid area
                if needsHorizontalScroll {
                    ScrollView(.horizontal, showsIndicators: false) {
                        gridInner(colWidth: colWidth)
                    }
                    .frame(width: availableForGrid)
                } else {
                    gridInner(colWidth: colWidth)
                        .frame(width: availableForGrid)
                }
            }
            .padding(.bottom, 100)
        }
    }

    private func gridInner(colWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Date headers
            HStack(spacing: 0) {
                ForEach(dateColumns, id: \.self) { dateKey in
                    dateHeader(for: dateKey)
                        .frame(width: colWidth, height: dateHeaderHeight)
                }
            }

            Rectangle()
                .fill(borderColor)
                .frame(height: 1)

            // Grid cells
            HStack(alignment: .top, spacing: 0) {
                ForEach(dateColumns, id: \.self) { dateKey in
                    VStack(spacing: 0) {
                        ForEach(timeSlots) { slot in
                            gridCell(dateKey: dateKey, slot: slot)
                                .frame(width: colWidth, height: cellHeight)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grid Cell

    private func gridCell(dateKey: String, slot: TimeSlot) -> some View {
        let cellKey = "\(dateKey)|\(slot.hour)|\(slot.minute)"
        let isSelected = selectedCells.contains(cellKey)
        let isBusy = useCalendar && calendarBusyCells.contains(cellKey)
        let isConflict = isSelected && isBusy
        let isHourBoundary = slot.minute == 0

        return ZStack {
            Rectangle()
                .fill(cellBackground(isSelected: isSelected, isBusy: isBusy, isConflict: isConflict))

            if isSelected {
                RoundedRectangle(cornerRadius: 3)
                    .fill(isConflict ? Color.orange.opacity(0.7) : accentBlue.opacity(0.6))
                    .padding(1.5)
            }
        }
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(isHourBoundary ? borderColor : borderColor.opacity(0.3)),
            alignment: .top
        )
        .overlay(
            Rectangle()
                .frame(width: 0.5)
                .foregroundColor(borderColor.opacity(0.3)),
            alignment: .trailing
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Haptic feedback
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()

            if selectedCells.contains(cellKey) {
                selectedCells.remove(cellKey)
            } else {
                selectedCells.insert(cellKey)
            }
        }
    }

    private func cellBackground(isSelected: Bool, isBusy: Bool, isConflict: Bool) -> Color {
        if isConflict { return Color.orange.opacity(0.15) }
        if isSelected { return accentBlue.opacity(0.1) }
        if isBusy { return Color(red: 0.2, green: 0.2, blue: 0.22) }
        return Color.clear
    }

    // MARK: - Date Header

    private func dateHeader(for dateKey: String) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let date = formatter.date(from: dateKey) ?? Date()

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let dayName = dayFormatter.string(from: date)

        let numFormatter = DateFormatter()
        numFormatter.dateFormat = "d"
        let dayNum = numFormatter.string(from: date)

        return VStack(spacing: 2) {
            Text(dayName.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(dimText)
            Text(dayNum)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedCells.isEmpty
                        ? "No time slots selected"
                        : "\(selectedCells.count) time \(selectedCells.count == 1 ? "slot" : "slots") selected")
                        .font(.caption)
                        .foregroundColor(labelColor)

                    if conflictCount > 0 {
                        Text("\(conflictCount) \(conflictCount == 1 ? "conflict" : "conflicts") with calendar")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                if !selectedCells.isEmpty {
                    Button("Clear all") {
                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                        feedback.impactOccurred()
                        selectedCells.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(dimText)
                }
            }

            Button(action: {
                if !selectedCells.isEmpty {
                    let feedback = UINotificationFeedbackGenerator()
                    feedback.notificationOccurred(.success)
                }
                onSave(selectedCells)
            }) {
                Text(selectedCells.isEmpty ? "Select Time Slots" : "Save Availability")
                    .font(.body.weight(.semibold))
                    .foregroundColor(selectedCells.isEmpty ? Color(red: 0.44, green: 0.44, blue: 0.48) : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedCells.isEmpty ? Color(red: 0.15, green: 0.15, blue: 0.18) : accentBlue)
                    .cornerRadius(14)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bgColor)
    }

    // MARK: - Helpers

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(dimText)
        }
    }
}
