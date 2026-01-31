import SwiftUI

struct ContentView: View {
    private let baseURL = URL(string: "https://timetogether.app")!

    var body: some View {
        WebView(url: baseURL)
            .ignoresSafeArea()
    }
}
