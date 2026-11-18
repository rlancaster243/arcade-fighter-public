import Foundation
import FightCore

enum FightSimCLI {
    struct Options: Sendable {
        var batchSeed: UInt64 = 0xA11CE
        var matchCount: Int32 = 1
        var ticksPerMatch: Int32 = MatchRules.roundTickLimit
        var p1Difficulty: Difficulty = .normal
        var p2Difficulty: Difficulty = .normal
        var jsonToStdout: Bool = true
        var jsonOutputPath: String?
    }

    static func parseArguments(_ args: [String]) -> Options? {
        var opt = Options()
        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--seed":
                i += 1
                guard i < args.count, let v = parseUInt64(args[i]) else { return nil }
                opt.batchSeed = v
            case "--batch", "--matches":
                i += 1
                guard i < args.count, let v = Int32(args[i]) else { return nil }
                opt.matchCount = max(1, v)
            case "--ticks":
                i += 1
                guard i < args.count, let v = Int32(args[i]) else { return nil }
                opt.ticksPerMatch = max(1, v)
            case "--p1":
                i += 1
                guard i < args.count, let d = parseDifficulty(args[i]) else { return nil }
                opt.p1Difficulty = d
            case "--p2":
                i += 1
                guard i < args.count, let d = parseDifficulty(args[i]) else { return nil }
                opt.p2Difficulty = d
            case "--json-out":
                i += 1
                guard i < args.count else { return nil }
                opt.jsonOutputPath = args[i]
            case "--help", "-h":
                printUsage()
                exit(0)
            default:
                return nil
            }
            i += 1
        }
        return opt
    }

    static func run(options: Options) throws {
        let config = FightSimBatchConfig(
            batchSeed: options.batchSeed,
            matchCount: options.matchCount,
            ticksPerMatch: options.ticksPerMatch,
            p1Difficulty: options.p1Difficulty,
            p2Difficulty: options.p2Difficulty
        )
        let report = AIMatchDriver.runBatch(config)
        let data = try JSONEncoder().encode(report)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CLIError.encodeFailed
        }
        if let path = options.jsonOutputPath {
            try text.write(toFile: path, atomically: true, encoding: .utf8)
        }
        if options.jsonToStdout {
            print(text)
        }
    }

    private enum CLIError: Error {
        case encodeFailed
    }

    private static func parseUInt64(_ s: String) -> UInt64? {
        if s.hasPrefix("0x") || s.hasPrefix("0X") {
            return UInt64(s.dropFirst(2), radix: 16)
        }
        return UInt64(s)
    }

    private static func parseDifficulty(_ s: String) -> Difficulty? {
        switch s.lowercased() {
        case "easy", "0": return .easy
        case "normal", "1": return .normal
        case "hard", "2": return .hard
        default: return nil
        }
    }

    static func printUsage() {
        let usage = """
        FightSim — headless seeded CPU-vs-CPU batch harness (JSON report).

        Usage:
          swift run FightSim [--seed N|0xN] [--batch N] [--ticks N] [--p1 easy|normal|hard] [--p2 easy|normal|hard] [--json-out path]

        Defaults: batch 1, ticks \(MatchRules.roundTickLimit), both normal, JSON on stdout.
        """
        print(usage)
    }
}