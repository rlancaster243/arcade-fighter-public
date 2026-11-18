public struct CollisionMatchContext: Sendable, Equatable {
  public var fighterDefs: [FighterDef]
  public var playLeftPx: Int32
  public var playRightPx: Int32

  public init(
    fighterDefs: [FighterDef] = [],
    playLeftPx: Int32 = StageBounds.playLeftPx,
    playRightPx: Int32 = StageBounds.playRightPx
  ) {
    self.fighterDefs = fighterDefs
    self.playLeftPx = playLeftPx
    self.playRightPx = playRightPx
  }

    public func def(for slot: PlayerSlot, snapshot: GameSnapshot) -> FighterDef? {
        let idx = Int(slot.rawValue)
        guard idx < fighterDefs.count else { return nil }
        if idx < snapshot.fighterIDs.count {
            let id = snapshot.fighterIDs[idx]
            if fighterDefs[idx].id == id {
                return fighterDefs[idx]
            }
            return fighterDefs.first { $0.id == id }
        }
        return fighterDefs[idx]
    }
}