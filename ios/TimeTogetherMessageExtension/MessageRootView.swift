import Messages
import SwiftUI
import WebKit

final class WebViewStore: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var webView: WKWebView
    @Published var currentURL: URL?
    @Published var isPollURL: Bool = false

    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
        let view = WKWebView()
        webView = view
        super.init()
        webView.navigationDelegate = self
    }

    func load(url: URL) {
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateState(from: webView.url)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        updateState(from: webView.url)
    }

    private func updateState(from url: URL?) {
        currentURL = url
        isPollURL = MessageURLValidator.isPollURL(url, baseURL: baseURL)
    }
}

struct MessageRootView: View {
    let conversation: MSConversation?
    let baseURL: URL?
    let onCreatePoll: () -> Void
    let onSendPoll: (URL) -> Void

    @ObservedObject var store: WebViewStore
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 12) {
            if let baseURL {
                WebViewContainer(webView: store.webView)
                    .cornerRadius(12)
            } else {
                EmptyStateView(
                    title: "Missing Configuration",
                    message: "Set WEB_BASE_URL in the extension Info.plist."
                )
            }

            Button(action: onCreatePoll) {
                Text("Create Poll")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(baseURL == nil)

            Button(action: sendMessage) {
                Text(isSending ? "Sending…" : "Send Poll")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSending || !store.isPollURL || conversation == nil)
        }
        .padding()
    }

    private func sendMessage() {
        guard !isSending, let url = store.currentURL else { return }
        isSending = true
        onSendPoll(url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isSending = false
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

enum MessageURLValidator {
    static func isPollURL(_ url: URL?, baseURL: URL) -> Bool {
        guard let url else { return false }
        guard url.host == baseURL.host else { return false }
        let path = url.path
        guard path.hasPrefix("/poll/") else { return false }
        let pollId = path.replacingOccurrences(of: "/poll/", with: "")
        return !pollId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
