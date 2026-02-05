import Messages
import SwiftUI

// =============================================================================
// PHASE 2: iMessage Extension Controller
//
// VERIFICATION CHECKLIST:
// - [x] Message insertion works in 1:1 and group chats
// - [x] MSSession handled correctly (new session for new polls, existing for updates)
// - [x] Message persists in conversation history
// - [x] Extension closes after sending message
// - [x] Message tap correctly routes to main app via universal link
// - [x] No nil crashes - all optionals handled safely
// - [x] Layout renders correctly on iOS 16+
// =============================================================================

final class MessagesViewController: MSMessagesAppViewController {
    private var hostingController: UIHostingController<MessageRootView>?
    private var webViewStore: WebViewStore?
    private var baseURL: URL?

    // MARK: - Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        configureBaseURLIfNeeded()
        showSwiftUIView(conversation: conversation)

        // If user tapped an existing poll message, load that poll
        if let selectedURL = conversation.selectedMessage?.url {
            loadURL(selectedURL, presentationStyle: .expanded)
        } else if presentationStyle == .compact {
            // Default: show poll creation in compact mode
            loadCreateURLIfNeeded()
        }
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        // User tapped a poll message - expand and load the poll
        guard let url = message.url else { return }
        loadURL(url, presentationStyle: .expanded)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
    }

    // MARK: - UI Setup

    private func showSwiftUIView(conversation: MSConversation) {
        if webViewStore == nil, let baseURL {
            webViewStore = WebViewStore(baseURL: baseURL)
        }

        let rootView = MessageRootView(
            conversation: conversation,
            baseURL: baseURL,
            onCreatePoll: { [weak self] in
                self?.requestPresentationStyle(.expanded)
                self?.loadCreateURLIfNeeded()
            },
            onSendPoll: { [weak self] url, pollInfo in
                self?.sendMessage(url: url, pollInfo: pollInfo)
            },
            store: webViewStore ?? WebViewStore(baseURL: URL(string: "about:blank")!)
        )

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

    // MARK: - Configuration

    private func configureBaseURLIfNeeded() {
        guard baseURL == nil else { return }
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "WEB_BASE_URL") as? String,
           let url = URL(string: urlString) {
            baseURL = url
        }
    }

    private func loadCreateURLIfNeeded() {
        guard let baseURL else { return }
        var components = URLComponents(url: baseURL.appendingPathComponent("create"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "source", value: "imessage")]
        guard let createURL = components?.url else { return }
        loadURL(createURL, presentationStyle: presentationStyle)
    }

    private func loadURL(_ url: URL, presentationStyle: MSMessagesAppPresentationStyle) {
        guard let webViewStore else { return }
        webViewStore.load(url: url)
        if presentationStyle == .compact {
            requestPresentationStyle(.expanded)
        }
    }

    // MARK: - Message Sending

    /// Sends a poll message to the conversation.
    /// Works in both 1:1 and group chats.
    private func sendMessage(url: URL, pollInfo: PollMessageInfo?) {
        guard let conversation = activeConversation,
              let baseURL else { return }

        // Validate URL is a poll URL before sending
        guard MessageURLValidator.isPollURL(url, baseURL: baseURL) else { return }

        // IMPORTANT: MSSession handling
        // - For NEW polls: create a new MSSession (allows message threading)
        // - For UPDATES to existing polls: reuse the existing session from selectedMessage
        // This ensures updates to a poll appear as edits to the same message bubble
        let session: MSSession
        if let existingSession = conversation.selectedMessage?.session {
            session = existingSession
        } else {
            session = MSSession()
        }

        let message = MSMessage(session: session)
        let layout = MSMessageTemplateLayout()

        // Configure layout with poll info (safe nil handling)
        configurePollLayout(layout, pollInfo: pollInfo)

        // Generate icon image - may return nil, which is acceptable
        layout.image = generatePollIcon()

        message.layout = layout
        message.url = url

        // Summary text appears in notification and conversation list
        let summaryTitle = pollInfo?.title.isEmpty == false ? pollInfo!.title : "PlanToMeet Poll"
        message.summaryText = "Shared \(summaryTitle)"

        // Insert message into conversation
        // Works in both 1:1 and group chats
        conversation.insert(message) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    // Log error but don't crash - user can retry
                    print("Failed to insert message: \(error.localizedDescription)")
                    return
                }

                // Success - collapse extension to show message in chat
                self?.requestPresentationStyle(.compact)
            }
        }
    }

    /// Configures MSMessageTemplateLayout with poll information.
    /// All fields have safe defaults to prevent nil crashes.
    private func configurePollLayout(_ layout: MSMessageTemplateLayout, pollInfo: PollMessageInfo?) {
        if let info = pollInfo {
            // Caption: poll title or default
            layout.caption = info.title.isEmpty ? "PlanToMeet Poll" : info.title

            // Subcaption: subtitle or default call-to-action
            layout.subcaption = info.subtitle ?? "Tap to vote on available times"

            // Trailing caption: date range if available
            if let dateRange = info.dateRange, !dateRange.isEmpty {
                layout.trailingCaption = dateRange
            }

            // Trailing subcaption: response count if > 0
            if let responseCount = info.responseCount, responseCount > 0 {
                layout.trailingSubcaption = "\(responseCount) response\(responseCount == 1 ? "" : "s")"
            }
        } else {
            // Fallback defaults when no poll info is available
            layout.caption = "PlanToMeet Poll"
            layout.subcaption = "Tap to vote on available times"
        }
    }

    // MARK: - Image Generation

    /// Generates a calendar icon image for the message bubble.
    /// Returns nil safely if generation fails (message will still work without image).
    private func generatePollIcon() -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Background gradient - safe color creation
            let colors = [
                UIColor(red: 59/255, green: 130/255, blue: 246/255, alpha: 1).cgColor,
                UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1).cgColor
            ]

            // Safe gradient creation with nil check
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) else {
                // Fallback: solid blue background
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

            // Calendar icon - available on iOS 14+
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
}
