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
            let title = info.title.isEmpty ? "PlanToMeet Poll" : info.title
            if let dateRange = info.dateRange, !dateRange.isEmpty {
                layout.caption = "\(title) · \(dateRange)"
            } else {
                layout.caption = title
            }
            layout.subcaption = info.subtitle ?? "Tap to vote"
            layout.trailingCaption = nil
            layout.trailingSubcaption = nil
            layout.image = renderPollCardImage(info)
        } else {
            layout.caption = "PlanToMeet Poll"
            layout.subcaption = "Tap to vote"
            layout.trailingCaption = nil
            layout.trailingSubcaption = nil
            layout.image = renderPollCardImage(nil)
        }
    }

    private func configureFinalizedLayout(_ layout: MSMessageTemplateLayout, info: FinalizedPollInfo) {
        let title = info.title.isEmpty ? "Event Scheduled" : info.title
        layout.caption = "✅ \(title) · \(info.formattedShortDate)"
        layout.subcaption = "Tap to add to calendar"
        layout.trailingCaption = nil
        layout.trailingSubcaption = nil
        layout.image = renderFinalizedCardImage(info)
    }

    private func renderPollCardImage(_ info: PollMessageInfo?) -> UIImage? {
        let size = CGSize(width: 900, height: 520)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let context = ctx.cgContext

            let backgroundColors = [
                UIColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1).cgColor,
                UIColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1).cgColor
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: backgroundColors as CFArray, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: rect.maxY), options: [])
            }

            context.setStrokeColor(UIColor.white.withAlphaComponent(0.04).cgColor)
            context.setLineWidth(1)
            let gridSpacing: CGFloat = 80
            stride(from: 0, through: rect.maxX, by: gridSpacing).forEach { x in
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
            stride(from: 0, through: rect.maxY, by: gridSpacing).forEach { y in
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
            context.strokePath()

            let cardRect = rect.insetBy(dx: 70, dy: 90)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 44)
            context.setFillColor(UIColor(red: 0.08, green: 0.1, blue: 0.16, alpha: 0.9).cgColor)
            context.addPath(cardPath.cgPath)
            context.fillPath()

            context.setStrokeColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            context.setLineWidth(2)
            context.addPath(cardPath.cgPath)
            context.strokePath()

            let innerPath = UIBezierPath(roundedRect: cardRect.insetBy(dx: 2, dy: 2), cornerRadius: 42)
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.08).cgColor)
            context.setLineWidth(1)
            context.addPath(innerPath.cgPath)
            context.strokePath()

            let orbRect = CGRect(x: cardRect.maxX - 70, y: cardRect.minY + 28, width: 36, height: 36)
            context.setFillColor(UIColor(red: 0.55, green: 0.64, blue: 1, alpha: 0.6).cgColor)
            context.fillEllipse(in: orbRect)

            let rawTitle = info?.title ?? ""
            let titleText = rawTitle.isEmpty ? "PlanToMeet Poll" : rawTitle
            let subtitleText = info?.subtitle ?? "Tap to vote"
            let dateText = info?.dateRange ?? ""

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.5)
            ]

            let titlePoint = CGPoint(x: cardRect.minX + 32, y: cardRect.minY + 70)
            titleText.draw(at: titlePoint, withAttributes: titleAttributes)

            let subtitlePoint = CGPoint(x: cardRect.minX + 32, y: cardRect.minY + 120)
            subtitleText.draw(at: subtitlePoint, withAttributes: subtitleAttributes)

            if !dateText.isEmpty {
                let datePoint = CGPoint(x: cardRect.minX + 32, y: cardRect.minY + 160)
                dateText.draw(at: datePoint, withAttributes: dateAttributes)
            }
        }
    }

    private func renderFinalizedCardImage(_ info: FinalizedPollInfo) -> UIImage? {
        let size = CGSize(width: 900, height: 520)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let context = ctx.cgContext
            context.setFillColor(UIColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1).cgColor)
            context.fill(rect)

            let cardRect = rect.insetBy(dx: 70, dy: 120)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 40)
            context.setFillColor(UIColor(red: 0.08, green: 0.12, blue: 0.1, alpha: 0.9).cgColor)
            context.addPath(cardPath.cgPath)
            context.fillPath()
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.16).cgColor)
            context.setLineWidth(2)
            context.addPath(cardPath.cgPath)
            context.strokePath()

            let title = info.title.isEmpty ? "Event Scheduled" : info.title
            let caption = "\(info.formattedShortDate)"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]

            title.draw(at: CGPoint(x: cardRect.minX + 32, y: cardRect.minY + 70), withAttributes: titleAttributes)
            caption.draw(at: CGPoint(x: cardRect.minX + 32, y: cardRect.minY + 120), withAttributes: subtitleAttributes)
        }
    }

}
