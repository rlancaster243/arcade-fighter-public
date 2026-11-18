import FightCore

/// Events surfaced on the key-test screen (platform adapters append; UI reads).
public struct KeyTestEvent: Sendable, Equatable, Identifiable {
    public let id: UInt64
    public let keyCode: UInt16
    public let label: String
    public let player: PlayerSlot?
    public let slot: KeyRemapSlot?
    public let isKeyDown: Bool

    public init(
        id: UInt64,
        keyCode: UInt16,
        label: String,
        player: PlayerSlot? = nil,
        slot: KeyRemapSlot? = nil,
        isKeyDown: Bool
    ) {
        self.id = id
        self.keyCode = keyCode
        self.label = label
        self.player = player
        self.slot = slot
        self.isKeyDown = isKeyDown
    }
}

public struct KeyTestModel: Sendable, Equatable {
    public private(set) var recent: [KeyTestEvent] = []
    public let maxEvents = 32
    private var nextID: UInt64 = 0

    public init() {}

    public mutating func record(
        keyCode: UInt16,
        label: String,
        player: PlayerSlot? = nil,
        slot: KeyRemapSlot? = nil,
        isKeyDown: Bool
    ) {
        nextID &+= 1
        let event = KeyTestEvent(
            id: nextID,
            keyCode: keyCode,
            label: label,
            player: player,
            slot: slot,
            isKeyDown: isKeyDown
        )
        recent.insert(event, at: 0)
        if recent.count > maxEvents {
            recent.removeLast(recent.count - maxEvents)
        }
    }

    public mutating func clear() {
        recent.removeAll(keepingCapacity: true)
    }
}