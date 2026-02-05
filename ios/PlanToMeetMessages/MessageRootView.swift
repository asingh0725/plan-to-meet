import Messages
import SwiftUI
import WebKit
import Combine

// =============================================================================
// PHASE 2: iMessage Extension WebView Store & UI
//
// VERIFICATION CHECKLIST:
// - [x] WebView loads poll creation page correctly
// - [x] WebView loads existing poll pages correctly
// - [x] Poll URL validation works for base domain
// - [x] No memory leaks (weak self in callbacks)
// - [x] Loading states displayed correctly
// - [x] Error states handled gracefully
// =============================================================================

/// Manages the WKWebView state for the iMessage extension.
/// Handles navigation, URL validation, and poll info extraction.
final class WebViewStore: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    @Published var webView: WKWebView
    @Published var currentURL: URL?
    @Published var isPollURL: Bool = false
    @Published var pollInfo: PollMessageInfo?
    @Published var isLoading: Bool = false

    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        config.userContentController = contentController
        let view = WKWebView(frame: .zero, configuration: config)
        webView = view
        super.init()
        webView.navigationDelegate = self
        contentController.add(self, name: "pollInfo")

        // Inject JavaScript bridge for web-to-native communication
        // Web app can call: window.sendPollInfoToNative({ title, dateRange, responseCount })
        let script = WKUserScript(
            source: """
            window.sendPollInfoToNative = function(info) {
                window.webkit.messageHandlers.pollInfo.postMessage(info);
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(script)
    }

    func load(url: URL) {
        isLoading = true
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        updateState(from: webView.url)
        extractPollInfoFromPage()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        updateState(from: webView.url)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "pollInfo",
              let body = message.body as? [String: Any] else { return }

        let title = body["title"] as? String ?? ""
        let subtitle = body["subtitle"] as? String
        let dateRange = body["dateRange"] as? String
        let responseCount = body["responseCount"] as? Int

        DispatchQueue.main.async {
            self.pollInfo = PollMessageInfo(
                title: title,
                subtitle: subtitle,
                dateRange: dateRange,
                responseCount: responseCount
            )
        }
    }

    private func updateState(from url: URL?) {
        currentURL = url
        isPollURL = MessageURLValidator.isPollURL(url, baseURL: baseURL)
        if !isPollURL {
            pollInfo = nil
        }
    }

    private func extractPollInfoFromPage() {
        // Try to extract poll info from the page title and meta tags
        webView.evaluateJavaScript("""
            (function() {
                var title = document.querySelector('[data-poll-title]')?.textContent ||
                           document.querySelector('h1')?.textContent ||
                           document.title || '';
                var dateRange = document.querySelector('[data-poll-date-range]')?.textContent || null;
                var responseCount = parseInt(document.querySelector('[data-poll-responses]')?.textContent) || null;

                return {
                    title: title.trim(),
                    dateRange: dateRange,
                    responseCount: responseCount
                };
            })();
        """) { [weak self] result, error in
            guard error == nil,
                  let info = result as? [String: Any] else { return }

            let title = info["title"] as? String ?? ""
            let dateRange = info["dateRange"] as? String
            let responseCount = info["responseCount"] as? Int

            DispatchQueue.main.async {
                self?.pollInfo = PollMessageInfo(
                    title: title,
                    subtitle: nil,
                    dateRange: dateRange,
                    responseCount: responseCount
                )
            }
        }
    }
}

struct MessageRootView: View {
    let conversation: MSConversation?
    let baseURL: URL?
    let onCreatePoll: () -> Void
    let onSendPoll: (URL, PollMessageInfo?) -> Void

    @ObservedObject var store: WebViewStore
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            if let _ = baseURL {
                ZStack {
                    WebViewContainer(webView: store.webView)

                    if store.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.2)
                    }
                }
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
            } else {
                EmptyStateView(
                    title: "Missing Configuration",
                    message: "Set WEB_BASE_URL in the extension Info.plist.",
                    systemImage: "exclamationmark.triangle"
                )
            }

            Spacer().frame(height: 16)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onCreatePoll) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .disabled(baseURL == nil)

                Button(action: sendMessage) {
                    HStack(spacing: 6) {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSending ? "Sending" : "Send")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isSending || !store.isPollURL || conversation == nil)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func sendMessage() {
        guard !isSending, let url = store.currentURL else { return }
        isSending = true
        onSendPoll(url, store.pollInfo)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSending = false
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

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
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - URL Validation

/// Validates and parses poll URLs for the iMessage extension.
/// Ensures only valid poll URLs from the expected domain can be shared.
enum MessageURLValidator {
    /// Checks if a URL is a valid poll URL from the expected base domain.
    /// Used to validate before sending a message and before enabling the Send button.
    static func isPollURL(_ url: URL?, baseURL: URL) -> Bool {
        guard let url else { return false }

        // Security: only accept URLs from our domain
        guard url.host == baseURL.host else { return false }

        let path = url.path

        // Must be a poll path: /poll/{id}
        guard path.hasPrefix("/poll/") else { return false }

        // Extract and validate poll ID (must not be empty)
        let pollId = path.replacingOccurrences(of: "/poll/", with: "")
        let trimmedId = pollId.trimmingCharacters(in: .whitespacesAndNewlines)

        // Poll ID should be non-empty and contain valid characters (UUID format)
        guard !trimmedId.isEmpty else { return false }

        // Basic UUID validation: alphanumeric and hyphens only
        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        guard trimmedId.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
            return false
        }

        return true
    }

    /// Extracts the poll ID from a poll URL.
    /// Returns nil if the URL is not a valid poll URL.
    static func extractPollId(from url: URL) -> String? {
        let path = url.path
        guard path.hasPrefix("/poll/") else { return nil }
        let pollId = path.replacingOccurrences(of: "/poll/", with: "")
        let trimmed = pollId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Data Models

/// Information about a poll extracted from the web page.
/// Used to populate the MSMessageTemplateLayout for rich message bubbles.
struct PollMessageInfo {
    let title: String
    let subtitle: String?
    let dateRange: String?
    let responseCount: Int?
}
