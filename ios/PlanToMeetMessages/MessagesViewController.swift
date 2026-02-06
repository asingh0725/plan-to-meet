import Messages
import SwiftUI
import UIKit

final class MessagesViewController: MSMessagesAppViewController {
    private var hostingController: UIHostingController<AnyView>?

    // Haptic feedback generators
    private let successFeedback = UINotificationFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        presentView(for: conversation)
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        presentView(for: conversation)
    }

    // MARK: - Routing

    private func presentView(for conversation: MSConversation) {
        if let selectedURL = conversation.selectedMessage?.url {
            // Check if this is a finalized poll (add to calendar)
            if let components = URLComponents(url: selectedURL, resolvingAgainstBaseURL: false),
               let finalizedParam = components.queryItems?.first(where: { $0.name == "finalized" })?.value,
               finalizedParam == "true" {
                showAddToCalendar(from: selectedURL)
            } else if let pollId = MessageURLValidator.extractPollId(from: selectedURL) {
                showPollDetail(pollId: pollId, conversation: conversation)
            } else {
                showPollForm(conversation: conversation)
            }
        } else {
            showPollForm(conversation: conversation)
        }
    }

    // MARK: - UI Setup

    private func showPollForm(conversation: MSConversation) {
        let vm = PollFormViewModel()

        let formView = PollFormView(viewModel: vm) { [weak self] url, pollInfo in
            self?.sendMessage(url: url, pollInfo: pollInfo, conversation: conversation)
        }

        presentHostedView(AnyView(formView))
    }

    private func showPollDetail(pollId: String, conversation: MSConversation) {
        let vm = PollDetailViewModel(pollId: pollId)
        let detailView = PollDetailView(
            viewModel: vm,
            onDismiss: { [weak self] in
                // Just collapse the extension - user can tap away to fully dismiss
                self?.requestPresentationStyle(.compact)
            },
            onFinalize: { [weak self] info in
                self?.sendFinalizedMessage(info: info, conversation: conversation)
            }
        )
        presentHostedView(AnyView(detailView))
    }

    private func showAddToCalendar(from url: URL) {
        guard let info = parseFinalizedInfo(from: url) else {
            // Fallback to form if parsing fails
            if let conversation = activeConversation {
                showPollForm(conversation: conversation)
            }
            return
        }

        let calendarView = AddToCalendarView(
            info: info,
            onDismiss: { [weak self] in
                self?.requestPresentationStyle(.compact)
            },
            onAdded: { [weak self] in
                // Optionally collapse after adding
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self?.requestPresentationStyle(.compact)
                }
            }
        )
        presentHostedView(AnyView(calendarView))
    }

    private func presentHostedView(_ rootView: AnyView) {
        if let hostingController {
            hostingController.rootView = rootView
            return
        }

        let controller = UIHostingController(rootView: rootView)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(controller)
        view.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        controller.didMove(toParent: self)
        hostingController = controller
    }

    // MARK: - Parse Finalized Info from URL

    private func parseFinalizedInfo(from url: URL) -> FinalizedPollInfo? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let queryItems = components.queryItems ?? []

        guard let pollId = queryItems.first(where: { $0.name == "pollId" })?.value,
              let title = queryItems.first(where: { $0.name == "title" })?.value?.removingPercentEncoding,
              let slotId = queryItems.first(where: { $0.name == "slotId" })?.value,
              let day = queryItems.first(where: { $0.name == "day" })?.value?.removingPercentEncoding,
              let startTime = queryItems.first(where: { $0.name == "startTime" })?.value?.removingPercentEncoding,
              let endTime = queryItems.first(where: { $0.name == "endTime" })?.value?.removingPercentEncoding,
              let durationStr = queryItems.first(where: { $0.name == "duration" })?.value,
              let duration = Int(durationStr) else {
            return nil
        }

        return FinalizedPollInfo(
            pollId: pollId,
            title: title,
            slotId: slotId,
            day: day,
            startTime: startTime,
            endTime: endTime,
            durationMinutes: duration
        )
    }

    // MARK: - Message Sending

    private func sendMessage(url: URL, pollInfo: PollMessageInfo?, conversation: MSConversation) {
        // Prepare haptic feedback
        successFeedback.prepare()

        let session: MSSession
        if let existingSession = conversation.selectedMessage?.session {
            session = existingSession
        } else {
            session = MSSession()
        }

        let message = MSMessage(session: session)
        let layout = MSMessageTemplateLayout()

        configurePollLayout(layout, pollInfo: pollInfo)
        layout.image = generatePollIcon()

        message.layout = layout
        message.url = url

        let summaryTitle = pollInfo?.title.isEmpty == false ? pollInfo!.title : "PlanToMeet Poll"
        message.summaryText = "Shared \(summaryTitle)"

        conversation.insert(message) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to insert message: \(error.localizedDescription)")
                    return
                }
                // Success haptic and dismiss
                self?.successFeedback.notificationOccurred(.success)
                self?.dismiss()
            }
        }
    }

    private func sendFinalizedMessage(info: FinalizedPollInfo, conversation: MSConversation) {
        // Prepare haptic feedback
        successFeedback.prepare()

        let session: MSSession
        if let existingSession = conversation.selectedMessage?.session {
            session = existingSession
        } else {
            session = MSSession()
        }

        let message = MSMessage(session: session)
        let layout = MSMessageTemplateLayout()

        configureFinalizedLayout(layout, info: info)
        layout.image = generateFinalizedIcon()

        // Build URL with finalized parameters
        var components = URLComponents(string: "\(AppConstants.webBaseURL)/poll/\(info.pollId)")!
        components.queryItems = [
            URLQueryItem(name: "finalized", value: "true"),
            URLQueryItem(name: "pollId", value: info.pollId),
            URLQueryItem(name: "title", value: info.title),
            URLQueryItem(name: "slotId", value: info.slotId),
            URLQueryItem(name: "day", value: info.day),
            URLQueryItem(name: "startTime", value: info.startTime),
            URLQueryItem(name: "endTime", value: info.endTime),
            URLQueryItem(name: "duration", value: String(info.durationMinutes))
        ]

        message.layout = layout
        message.url = components.url

        let title = info.title.isEmpty ? "Event" : info.title
        message.summaryText = "\(title) scheduled for \(info.formattedShortDate)"

        conversation.insert(message) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to insert finalized message: \(error.localizedDescription)")
                    return
                }
                // Success haptic and dismiss
                self?.successFeedback.notificationOccurred(.success)
                self?.dismiss()
            }
        }
    }

    // MARK: - Dismiss Helper

    override func dismiss() {
        requestPresentationStyle(.compact)
    }

    private func configurePollLayout(_ layout: MSMessageTemplateLayout, pollInfo: PollMessageInfo?) {
        if let info = pollInfo {
            layout.caption = info.title.isEmpty ? "PlanToMeet Poll" : info.title
            layout.subcaption = info.subtitle ?? "Tap to vote on available times"

            if let dateRange = info.dateRange, !dateRange.isEmpty {
                layout.trailingCaption = dateRange
            }

            if let responseCount = info.responseCount, responseCount > 0 {
                layout.trailingSubcaption = "\(responseCount) response\(responseCount == 1 ? "" : "s")"
            }
        } else {
            layout.caption = "PlanToMeet Poll"
            layout.subcaption = "Tap to vote on available times"
        }
    }

    private func configureFinalizedLayout(_ layout: MSMessageTemplateLayout, info: FinalizedPollInfo) {
        let title = info.title.isEmpty ? "Event Scheduled" : info.title
        layout.caption = "✅ \(title)"
        layout.subcaption = "\(info.formattedShortDate) at \(info.formattedTime)"
        layout.trailingCaption = "Tap to add"
        layout.trailingSubcaption = "to calendar"
    }

    // MARK: - Image Generation

    private func generatePollIcon() -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let colors = [
                UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1).cgColor,
                UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1).cgColor
            ]

            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) else {
                UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1).setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 40).fill()
                return
            }

            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 40)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.clip()

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            let iconConfig = UIImage.SymbolConfiguration(pointSize: 120, weight: .medium)
            if let calendarIcon = UIImage(systemName: "calendar.badge.clock", withConfiguration: iconConfig) {
                let tinted = calendarIcon.withTintColor(.white, renderingMode: .alwaysOriginal)
                let iconSize = tinted.size
                let iconOrigin = CGPoint(
                    x: (size.width - iconSize.width) / 2,
                    y: (size.height - iconSize.height) / 2
                )
                tinted.draw(at: iconOrigin)
            }
        }
    }

    private func generateFinalizedIcon() -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Green gradient for finalized
            let colors = [
                UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1).cgColor,
                UIColor(red: 22/255, green: 163/255, blue: 74/255, alpha: 1).cgColor
            ]

            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) else {
                UIColor.green.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 40).fill()
                return
            }

            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 40)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.clip()

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            let iconConfig = UIImage.SymbolConfiguration(pointSize: 120, weight: .medium)
            if let checkIcon = UIImage(systemName: "calendar.badge.checkmark", withConfiguration: iconConfig) {
                let tinted = checkIcon.withTintColor(.white, renderingMode: .alwaysOriginal)
                let iconSize = tinted.size
                let iconOrigin = CGPoint(
                    x: (size.width - iconSize.width) / 2,
                    y: (size.height - iconSize.height) / 2
                )
                tinted.draw(at: iconOrigin)
            }
        }
    }
}
