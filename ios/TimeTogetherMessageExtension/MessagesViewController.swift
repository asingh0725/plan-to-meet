import Messages
import SwiftUI

final class MessagesViewController: MSMessagesAppViewController {
    private var hostingController: UIHostingController<MessageRootView>?
    private var webViewStore: WebViewStore?
    private var baseURL: URL?

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        configureBaseURLIfNeeded()
        showSwiftUIView(conversation: conversation)
        if let selectedURL = conversation.selectedMessage?.url {
            loadURL(selectedURL, presentationStyle: .expanded)
        } else if presentationStyle == .compact {
            loadCreateURLIfNeeded()
        }
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        guard let url = message.url else { return }
        loadURL(url, presentationStyle: .expanded)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
    }

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
            onSendPoll: { [weak self] url in
                self?.sendMessage(url: url)
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

    private func sendMessage(url: URL) {
        guard let conversation = activeConversation,
              let baseURL else { return }

        guard MessageURLValidator.isPollURL(url, baseURL: baseURL) else { return }

        let message = MSMessage()
        let layout = MSMessageTemplateLayout()
        layout.caption = "TimeTogether Poll"
        layout.subcaption = "Tap to vote"
        message.layout = layout
        message.url = url

        conversation.insert(message) { [weak self] _ in
            DispatchQueue.main.async {
                self?.requestPresentationStyle(.compact)
            }
        }
    }
}
