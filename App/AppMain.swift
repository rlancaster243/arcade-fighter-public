import SwiftUI

@main
struct ArcadeFighterApp: App {
    var body: some Scene {
        WindowGroup {
            ShellRootView()
                .frame(minWidth: 768, minHeight: 432)
        }
    }
}