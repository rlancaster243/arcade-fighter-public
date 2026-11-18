import Foundation

struct FighterJSON: Decodable {
    struct BoxJSON: Decodable {
        let x: Int32
        let y: Int32
        let w: Int32
        let h: Int32
    }

    struct JumpJSON: Decodable {
        let velocityY: Int32
        let gravity: Int32
    }

    struct HurtboxJSON: Decodable {
        let state: String
        let boxes: [BoxJSON]
    }

    struct MoveInputJSON: Decodable {
        let button: String?
        let stance: String?
        let motion: String?
    }

    struct MoveFramesJSON: Decodable {
        let hit: [BoxJSON]?
        let hurt: [BoxJSON]?
        let push: [BoxJSON]?
        let `throw`: [BoxJSON]?
    }

    struct VelocityJSON: Decodable {
        let x: Int32
        let y: Int32
    }

    struct ProjectileJSON: Decodable {
        let speed: Int32
        let lifetime: Int32
        let hitbox: BoxJSON
        let damage: Int32
        let maxOnScreen: Int32
        let spawnCount: Int32
        let hitsAirborne: Bool
    }

    struct CounterJSON: Decodable {
        let startTick: Int32
        let endTick: Int32
        let followUpMoveID: String
    }

    struct HitJSON: Decodable {
        let activeFrame: Int32
        let damage: Int32
        let hitstun: Int32
        let blockstun: Int32
        let hitstop: Int32
    }

    struct MoveJSON: Decodable {
        let id: String
        let name: String
        let sprite: String?
        let input: MoveInputJSON
        let startup: Int32
        let active: Int32
        let recovery: Int32
        let frames: MoveFramesJSON
        let damage: Int32
        let chip: Int32
        let hitstun: Int32
        let blockstun: Int32
        let pushbackHit: Int32
        let pushbackBlock: Int32
        let meterGain: Int32
        let hitstop: Int32
        let guardKind: String
        let unblockable: Bool?
        let armorHits: Int32?
        let projectile: ProjectileJSON?
        let velocities: [VelocityJSON]?
        let invulnerableFrames: [Int32]?
        let whiffsVsAirborne: Bool?
        let counter: CounterJSON?
        let hits: [HitJSON]?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case sprite
            case input
            case startup
            case active
            case recovery
            case frames
            case damage
            case chip
            case hitstun
            case blockstun
            case pushbackHit
            case pushbackBlock
            case meterGain
            case hitstop
            case guardKind = "guard"
            case unblockable
            case armorHits
            case projectile
            case velocities
            case invulnerableFrames
            case whiffsVsAirborne
            case counter
            case hits
        }
    }

    let schemaVersion: Int
    let id: String
    let displayName: String
    let archetype: String
    let gamePlan: String
    let health: Int32
    let walkForward: Int32
    let walkBack: Int32
    let jump: JumpJSON
    let pushbox: BoxJSON
    let hurtboxes: [HurtboxJSON]
    let spriteSheet: String
    let sheetMeta: String
    let moves: [MoveJSON]
}

struct SheetFrameJSON: Decodable {
    let name: String
    let x: Int32
    let y: Int32
    let w: Int32
    let h: Int32
    let anchorX: Int32
    let anchorY: Int32
}

func mapBox(_ b: FighterJSON.BoxJSON) -> Hitbox {
    Hitbox(x: b.x, y: b.y, w: b.w, h: b.h)
}

func parseGuard(_ raw: String) throws -> GuardLevel {
    switch raw.lowercased() {
    case "high": return .high
    case "mid": return .mid
    case "low": return .low
    case "throw": return .throwAttack
    default:
        throw FighterLoadError.invalidGuard(raw)
    }
}

func parseStateKind(_ raw: String) throws -> FighterStateKind {
    let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let k = FighterStateKind.allCases.first(where: { "\($0)" == key }) {
        return k
    }
  throw FighterLoadError.unknownState(key)
}

func classifyMoveInput(_ input: FighterJSON.MoveInputJSON) -> MoveInputKind {
    if let motion = input.motion, motion == "236236" { return .superMove }
    if input.motion != nil { return .special }
    if input.button == nil && input.stance == nil { return .normal }
    if input.stance == "throw" { return .throwMove }
    return .normal
}