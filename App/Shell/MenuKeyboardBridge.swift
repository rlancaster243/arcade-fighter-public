import AppLogic
import SwiftUI

#if os(macOS)
import AppKit

/// How menu keys are routed relative to fight input (`InputCoordinator`).
enum MenuKeyboardMode: Equatable {
    /// Menu first responder: navigation + confirm + pause/cancel.
    case fullNavigation
    /// During `.inMatch`: no navigation steal; only P / Esc via a local monitor.
    case matchPauseHotkeysOnly
}

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
            if let command = Self.pauseHotkeyCommand(for: event) {
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
        if let command = mapFullNavigation(event) {
            onCommand?(command)
        } else {
            super.keyDown(with: event)
        }
    }

    private func mapFullNavigation(_ event: NSEvent) -> MenuCommand? {
        switch event.keyCode {
        case 126, 13: return .up // up / W
        case 125, 1: return .down // down / S
        case 123, 0: return .left
        case 124, 2: return .right
        case 36, 49: return .confirm // return / space
        case 53: return .cancel // escape
        case 35: return .pause // P
        default:
            return nil
        }
    }

    private static func pauseHotkeyCommand(for event: NSEvent) -> MenuCommand? {
        switch event.keyCode {
        case 53: return .cancel
        case 35: return .pause
        default:
            return nil
        }
    }
}
#endif