import FightCore

@main
struct FightSimMain {
    static func main() {
        var sim = Simulation()
        var snap = SimulationBootstrap.greyboxMatch(seed: 0xBADA55)
        let ticks = 120
        var frames = [InputFrame(), InputFrame()]
        frames[0].direction = .right
        for _ in 0..<ticks {
            sim.step(inputs: frames, snapshot: &snap)
        }
        if snap.rules.matchOver {
            fputs("match ended early\n", stderr)
        }
    }
}