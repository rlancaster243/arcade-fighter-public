enum ProjectileLogic {
    static func spawnID(for snapshot: GameSnapshot) -> UInt32 {
        var maxID: UInt32 = 0
        for p in snapshot.projectiles where p.active {
            if p.id > maxID {
                maxID = p.id
            }
        }
        return maxID &+ 1
    }

    static func moveSpawnsProjectile(move: MoveDef, stateTick: Int32) -> Bool {
        guard MovePhaseMath.attackPhase(for: stateTick, move: move) == .active else {
            return false
        }
        if move.id == "sp_qcf" {
            return stateTick == move.startup
        }
        if move.id.hasSuffix("_shot") {
            return stateTick == move.startup
        }
        return false
    }

    static func makeProjectile(
        id: UInt32,
        owner: PlayerSlot,
        facingRight: Bool,
        move: MoveDef,
        position: Vec2
    ) -> Projectile {
        let speed = Fixed(pixels: facingRight ? 6 : -6)
        let hit = move.frames.hit.first ?? Hitbox(x: 10, y: -40, w: 24, h: 24)
        return Projectile(
            id: id,
            owner: owner,
            position: position,
            velocity: Vec2(x: speed, y: .zero),
            hitbox: hit,
            damage: move.damage,
            lifetimeTicks: 90,
            active: true
        )
    }

    static func stepProjectiles(_ projectiles: inout [Projectile]) {
        for i in projectiles.indices {
            guard projectiles[i].active else { continue }
            let v = projectiles[i].velocity
            projectiles[i].position = Vec2(
                x: Fixed(raw: projectiles[i].position.x.raw + v.x.raw),
                y: Fixed(raw: projectiles[i].position.y.raw + v.y.raw)
            )
            projectiles[i].lifetimeTicks &-= 1
            if projectiles[i].lifetimeTicks <= 0 {
                projectiles[i].active = false
            }
        }
        projectiles.removeAll { !$0.active }
    }
}