struct FighterRuntimeSlot: Sendable, Equatable {
    var armorHitsRemaining: Int32 = 0
    var queuedMoveID: String = ""
    var jumpQueued: Bool = false
    var executingMoveID: String = ""
}