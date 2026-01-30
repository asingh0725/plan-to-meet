import Messages
import SwiftUI

final class MessagesViewController: MSMessagesAppViewController {
    private var hostingController: UIHostingController<MessageRootView>?

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        showSwiftUIView(conversation: conversation)
    }

    private func showSwiftUIView(conversation: MSConversation) {
        let rootView = MessageRootView(conversation: conversation)
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
}
