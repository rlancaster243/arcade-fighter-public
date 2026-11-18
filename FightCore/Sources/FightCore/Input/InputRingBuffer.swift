/// Fixed-capacity ring of per-tick facing-normalised numpad inputs (32 frames).
public struct InputRingBuffer: Sendable, Equatable {
    public static let capacity = 32

    public struct Entry: Sendable, Equatable {
        public var numpad: UInt8
        public var buttons: UInt8

        public init(numpad: UInt8 = 0, buttons: UInt8 = 0) {
            self.numpad = numpad
            self.buttons = buttons
        }
    }

    private var storage: [Entry]
    private var count: Int
    private var head: Int

    public init() {
        storage = Array(repeating: Entry(), count: Self.capacity)
        count = 0
        head = 0
    }

    public var frameCount: Int { count }

    /// `ago` 0 is the most recently pushed frame.
    public func entry(ago: Int) -> Entry? {
        guard ago >= 0, ago < count else { return nil }
        let idx = (head - 1 - ago + Self.capacity) % Self.capacity
        return storage[idx]
    }

    public mutating func push(numpad: UInt8, buttons: UInt8) {
        storage[head] = Entry(numpad: numpad, buttons: buttons)
        head = (head + 1) % Self.capacity
        if count < Self.capacity {
            count += 1
        }
    }

    /// Mirror horizontal numpad values after a facing flip (logical ↔ screen remap).
    public mutating func applyFacingFlip() {
        guard count > 0 else { return }
        for i in 0 ..< count {
            let idx = (head - 1 - i + Self.capacity) % Self.capacity
            storage[idx].numpad = FacingInput.mirrorNumpad(storage[idx].numpad)
        }
    }
}