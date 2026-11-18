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
        guard let projectile = move.projectile else { return false }
        guard MovePhaseMath.attackPhase(for: stateTick, move: move) == .active else {
            return false
        }
        let activeIndex = stateTick - move.startup
        return activeIndex >= 0 && activeIndex < projectile.spawnCount
    }

    static func activeCount(ownedBy owner: PlayerSlot, in snapshot: GameSnapshot) -> Int32 {
        var count: Int32 = 0
        for projectile in snapshot.projectiles where projectile.active && projectile.owner == owner {
            count &+= 1
        }
        return count
    }

    static func makeProjectile(
        id: UInt32,
        owner: PlayerSlot,
        facingRight: Bool,
        spawn: ProjectileSpawn,
        position: Vec2
    ) -> Projectile {
        let speed = Fixed(raw: facingRight ? spawn.speed : -spawn.speed)
        return Projectile(
            id: id,
            owner: owner,
            position: position,
            velocity: Vec2(x: speed, y: .zero),
            hitbox: spawn.hitbox,
            damage: spawn.damage,
            lifetimeTicks: spawn.lifetime,
            active: true,
            hitsAirborne: spawn.hitsAirborne
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