import Foundation

public enum FighterLoadError: Error, Equatable, Sendable {
    case wrongSchemaVersion(Int)
    case duplicateMoveID(String)
    case negativeFrameCount(String)
    case frameBoxCountMismatch(String)
    case missingSpriteName(String)
    case unblockableNonThrow(String)
    case emptyGamePlan
    case invalidGuard(String)
    case unknownState(String)
    case fileNotFound(String)
    case decodeFailed(String)
    case missingSheetFile
    case negativeArmorHits(String)
    case invalidProjectileLifetime(String)
    case invalidProjectileSpawnCount(String)
    case invalidProjectileMaxOnScreen(String)
    case invalidProjectileDamage(String)
    case invalidProjectileHitbox(String)
    case velocityFrameCount(String)
    case invalidInvulnerableFrame(String)
    case whiffsVsAirborneNonThrow(String)
    case invalidCounterWindow(String)
    case missingCounterFollowUp(String)
    case invalidMultiHit(String)
    case negativeWalkSpeed
}