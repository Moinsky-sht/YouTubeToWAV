import SwiftUI

@main
struct YouTubeToWAVApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 480, maxWidth: 480, minHeight: 280, maxHeight: 280)
        }
        .windowResizability(.contentMinSize)
    }
}
