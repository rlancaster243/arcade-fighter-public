import AppLogic
import AppKit

/// `NSEvent` keyboard adapter: distinct numpad key codes, ignores `isARepeat`.
final class KeyboardInputAdapter {
    var onKeyDown: ((UInt16) -> Void)?
    var onKeyUp: ((UInt16) -> Void)?

    private var monitorDown: Any?
    private var monitorUp: Any?

    func startMonitoring() {
        stopMonitoring()
        monitorDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.isARepeat { return event }
            self.onKeyDown?(event.keyCode)
            return event
        }
        monitorUp = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.onKeyUp?(event.keyCode)
            return event
        }
    }

    func stopMonitoring() {
        if let monitorDown {
            NSEvent.removeMonitor(monitorDown)
            self.monitorDown = nil
        }
        if let monitorUp {
            NSEvent.removeMonitor(monitorUp)
            self.monitorUp = nil
        }
    }

    deinit {
        stopMonitoring()
    }
}

extension KeyboardInputAdapter {
    /// Sample keys for key-test UI using the shared virtual-key table.
    static func label(for keyCode: UInt16) -> String {
        MacVirtualKeyCode.displayLabel(for: keyCode)
    }
}