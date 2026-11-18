import AppLogic
import SwiftUI

#if os(macOS)
import AppKit

struct MenuKeyboardBridge: NSViewRepresentable {
    let mode: MenuKeyboardMode
    let onCommand: (MenuCommand) -> Void

    func makeNSView(context: Context) -> MenuKeyCatcherView {
        let view = MenuKeyCatcherView()
        view.onCommand = onCommand
        view.mode = mode
        return view
    }

    func updateNSView(_ nsView: MenuKeyCatcherView, context: Context) {
        nsView.onCommand = onCommand
        nsView.mode = mode
    }
}

final class MenuKeyCatcherView: NSView {
    var onCommand: ((MenuCommand) -> Void)?
    var mode = MenuKeyboardMode.fullNavigation {
        didSet {
            updateFirstResponder()
            updatePauseHotkeyMonitor()
        }
    }

    private var pauseHotkeyMonitor: Any?

    override var acceptsFirstResponder: Bool {
        mode == .fullNavigation
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateFirstResponder()
        updatePauseHotkeyMonitor()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            removePauseHotkeyMonitor()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    private func updateFirstResponder() {
        guard let window else { return }
        switch mode {
        case .fullNavigation:
            window.makeFirstResponder(self)
        case .matchPauseHotkeysOnly:
            if window.firstResponder === self {
                window.makeFirstResponder(nil)
            }
        }
    }

    private func updatePauseHotkeyMonitor() {
        switch mode {
        case .matchPauseHotkeysOnly:
            installPauseHotkeyMonitorIfNeeded()
        case .fullNavigation:
            removePauseHotkeyMonitor()
        }
    }

    private func installPauseHotkeyMonitorIfNeeded() {
        guard pauseHotkeyMonitor == nil else { return }
        pauseHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.mode == .matchPauseHotkeysOnly else { return event }
            if event.isARepeat { return event }
            if let command = MenuKeyboardRouting.menuCommand(keyCode: event.keyCode, mode: .matchPauseHotkeysOnly) {
                self.onCommand?(command)
                return nil
            }
            return event
        }
    }

    private func removePauseHotkeyMonitor() {
        if let pauseHotkeyMonitor {
            NSEvent.removeMonitor(pauseHotkeyMonitor)
            self.pauseHotkeyMonitor = nil
        }
    }

    deinit {
        removePauseHotkeyMonitor()
    }

    override func keyDown(with event: NSEvent) {
        guard mode == .fullNavigation else {
            super.keyDown(with: event)
            return
        }
        if event.isARepeat { return }
        if let command = MenuKeyboardRouting.menuCommand(keyCode: event.keyCode, mode: .fullNavigation) {
            onCommand?(command)
        } else {
            super.keyDown(with: event)
        }
    }
}
#endif