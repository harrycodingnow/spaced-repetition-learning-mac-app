import SwiftUI

@main
struct SRLMenuBarApp: App {
    @NSApplicationDelegateAdaptor(IslandAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
