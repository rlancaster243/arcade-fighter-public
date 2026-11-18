import AppLogic
import SwiftUI

#if os(macOS)
import AppKit

struct MenuKeyboardBridge: NSViewRepresentable {
    let isActive: Bool
    let onCommand: (MenuCommand) -> Void

    func makeNSView(context: Context) -> MenuKeyCatcherView {
        let view = MenuKeyCatcherView()
        view.onCommand = onCommand
        view.isActive = isActive
        return view
    }

    func updateNSView(_ nsView: MenuKeyCatcherView, context: Context) {
        nsView.onCommand = onCommand
        nsView.isActive = isActive
    }
}

final class MenuKeyCatcherView: NSView {
    var onCommand: ((MenuCommand) -> Void)?
    var isActive = true {
        didSet { updateFirstResponder() }
    }

    override var acceptsFirstResponder: Bool { isActive }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateFirstResponder()
    }

    private func updateFirstResponder() {
        guard let window else { return }
        if isActive {
            window.makeFirstResponder(self)
        } else if window.firstResponder === self {
            window.makeFirstResponder(nil)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isActive else {
            super.keyDown(with: event)
            return
        }
        if event.isARepeat { return }
        if let command = map(event) {
            onCommand?(command)
        } else {
            super.keyDown(with: event)
        }
    }

    private func map(_ event: NSEvent) -> MenuCommand? {
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
}
#endif