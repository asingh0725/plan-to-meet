import Messages
import SwiftUI
import WebKit

final class WebViewStore: ObservableObject {
    @Published var webView: WKWebView

    init(url: URL) {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        webView = view
    }
}

struct MessageRootView: View {
    let conversation: MSConversation
    @StateObject private var store: WebViewStore

    private static let baseURL = URL(string: "https://timetogether.app")!

    private static func createURL() -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("create"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "source", value: "imessage")]
        return components?.url ?? baseURL
    }

    init(conversation: MSConversation) {
        self.conversation = conversation
        _store = StateObject(wrappedValue: WebViewStore(url: Self.createURL()))
    }

    var body: some View {
        VStack(spacing: 12) {
            WebViewContainer(webView: store.webView)
                .cornerRadius(12)

            Button(action: sendMessage) {
                Text("Send Poll")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func sendMessage() {
        let message = MSMessage()
        let layout = MSMessageTemplateLayout()
        layout.caption = "TimeTogether Poll"
        layout.subcaption = "Tap to vote"
        message.layout = layout

        let url = store.webView.url ?? Self.baseURL
        message.url = url

        conversation.insert(message) { _ in }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
