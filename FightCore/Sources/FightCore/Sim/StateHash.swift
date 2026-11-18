/// FNV-1a 64-bit hash over canonical `GameSnapshot` bytes (no Foundation on hot path).
public enum StateHash {
    private static let offsetBasis: UInt64 = 0xCBF2_9CE4_8422_2325
    private static let prime: UInt64 = 0x0000_0100_0000_01B3

    public static func fnv1a64(_ data: [UInt8]) -> UInt64 {
        var hash = offsetBasis
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return hash
    }

    public static func canonicalBytes(of snapshot: GameSnapshot) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(512)
        appendVarint(snapshot.tick, to: &bytes)
        appendVarint(Int64(bitPattern: snapshot.rng.state), to: &bytes)
        appendStringList(snapshot.fighterIDs, to: &bytes)
        for f in snapshot.fighters {
            appendVarint(Int32(f.kind.rawValue), to: &bytes)
            appendVarint(f.timer, to: &bytes)
            appendVarint(f.position.x.raw, to: &bytes)
            appendVarint(f.position.y.raw, to: &bytes)
            appendVarint(f.velocity.x.raw, to: &bytes)
            appendVarint(f.velocity.y.raw, to: &bytes)
            bytes.append(f.facingRight ? 1 : 0)
            appendVarint(f.health, to: &bytes)
            appendVarint(f.meter, to: &bytes)
            appendString(f.activeMoveID, to: &bytes)
            appendVarint(f.stateTick, to: &bytes)
        }
        appendVarint(snapshot.projectiles.count, to: &bytes)
        for p in snapshot.projectiles {
            appendVarint(Int32(p.id), to: &bytes)
            appendVarint(Int32(p.owner.rawValue), to: &bytes)
            appendVarint(p.position.x.raw, to: &bytes)
            appendVarint(p.position.y.raw, to: &bytes)
            appendVarint(p.velocity.x.raw, to: &bytes)
            appendVarint(p.velocity.y.raw, to: &bytes)
            appendVarint(p.damage, to: &bytes)
            appendVarint(p.lifetimeTicks, to: &bytes)
            bytes.append(p.active ? 1 : 0)
        }
        let r = snapshot.rules
        appendVarint(r.roundNumber, to: &bytes)
        appendVarint(r.p1RoundsWon, to: &bytes)
        appendVarint(r.p2RoundsWon, to: &bytes)
        appendVarint(r.roundTick, to: &bytes)
        appendVarint(r.hitstopRemaining, to: &bytes)
        bytes.append(r.roundOver ? 1 : 0)
        bytes.append(r.matchOver ? 1 : 0)
        if let w = r.winner {
            bytes.append(1)
            bytes.append(w.rawValue)
        } else {
            bytes.append(0)
        }
        appendVarint(snapshot.events.count, to: &bytes)
        for e in snapshot.events {
            appendVarint(Int32(e.kind.rawValue), to: &bytes)
            appendVarint(e.tick, to: &bytes)
            appendVarint(Int32(e.attacker.rawValue), to: &bytes)
            appendVarint(Int32(e.defender.rawValue), to: &bytes)
            appendString(e.moveID, to: &bytes)
            appendVarint(e.damage, to: &bytes)
        }
        return bytes
    }

    public static func hash(of snapshot: GameSnapshot) -> UInt64 {
        fnv1a64(canonicalBytes(of: snapshot))
    }

    private static func appendVarint(_ value: Int32, to bytes: inout [UInt8]) {
        appendVarint(Int64(value), to: &bytes)
    }

    private static func appendVarint(_ value: Int64, to bytes: inout [UInt8]) {
        var v = value
        while true {
            if v >= -64 && v < 64 {
                bytes.append(UInt8(truncatingIfNeeded: v))
                return
            }
            bytes.append(UInt8(truncatingIfNeeded: (v & 0x7F) | 0x80))
            v >>= 7
        }
    }

    private static func appendString(_ s: String, to bytes: inout [UInt8]) {
        let utf8 = Array(s.utf8)
        appendVarint(Int32(utf8.count), to: &bytes)
        bytes.append(contentsOf: utf8)
    }

    private static func appendStringList(_ list: [String], to bytes: inout [UInt8]) {
        appendVarint(Int32(list.count), to: &bytes)
        for s in list {
            appendString(s, to: &bytes)
        }
    }
}

public extension GameSnapshot {
    func stateHash() -> UInt64 {
        StateHash.hash(of: self)
    }
}