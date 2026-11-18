import AppLogic
import AppKit
import SwiftUI

/// Applies menu `DisplayPreferences` to the host `NSWindow` (windowed integer scale vs fullscreen).
enum WindowPresentation {
    static func apply(_ preferences: AppPreferences, to window: NSWindow?) {
        guard let window else { return }
        if preferences.display.wantsFullscreen {
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
        } else if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }

        let size = DisplayLayout.minWindowSize(scale: preferences.display.windowIntegerScale)
        let content = CGSize(width: size.width, height: size.height)
        window.setContentSize(content)
        window.minSize = content
    }
}

struct WindowPreferencesModifier: ViewModifier {
    let preferences: AppPreferences

    func body(content: Content) -> some View {
        content
            .onAppear { syncWindow() }
            .onChange(of: preferences) { _, newValue in
                syncWindow(preferences: newValue)
            }
    }

    private func syncWindow(preferences: AppPreferences? = nil) {
        let prefs = preferences ?? self.preferences
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }) else { return }
        WindowPresentation.apply(prefs, to: window)
    }
}

extension View {
    func windowPreferences(_ preferences: AppPreferences) -> some View {
        modifier(WindowPreferencesModifier(preferences: preferences))
    }
}