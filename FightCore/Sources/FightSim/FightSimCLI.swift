import Foundation
import FightCore

enum FightSimStdio {
    static func writeError(_ text: String) {
        let line = text.hasSuffix("\n") ? text : text + "\n"
        guard let data = line.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}

enum FightSimCLI {
    struct Options: Sendable {
        var batchSeed: UInt64 = 0xA11CE
        var matchCount: Int32 = 1
        var ticksPerMatch: Int32 = MatchRules.roundTickLimit
        var p1Difficulty: Difficulty = .normal
        var p2Difficulty: Difficulty = .normal
        var jsonToStdout: Bool = true
        var jsonOutputPath: String?
        var roster = false
        var p1FighterID: String?
        var p2FighterID: String?
        var stageID = "stage1"
        var seedStart: UInt64 = 1
        var seedEnd: UInt64 = 1
        var rosterTickLimit: Int32 = MatchRules.roundTickLimit * MatchRules.maxRounds * 2
        var progress = false
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
            case "--roster":
                opt.roster = true
            case "--p1-fighter":
                i += 1
                guard i < args.count else { return nil }
                opt.p1FighterID = args[i]
                opt.roster = true
            case "--p2-fighter":
                i += 1
                guard i < args.count else { return nil }
                opt.p2FighterID = args[i]
                opt.roster = true
            case "--stage":
                i += 1
                guard i < args.count else { return nil }
                opt.stageID = args[i]
            case "--seed-start":
                i += 1
                guard i < args.count, let v = parseUInt64(args[i]) else { return nil }
                opt.seedStart = v
            case "--seed-end":
                i += 1
                guard i < args.count, let v = parseUInt64(args[i]) else { return nil }
                opt.seedEnd = v
            case "--tick-limit":
                i += 1
                guard i < args.count, let v = Int32(args[i]), v > 0 else { return nil }
                opt.rosterTickLimit = v
            case "--progress":
                opt.progress = true
            case "--quiet":
                opt.jsonToStdout = false
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
        if options.roster {
            try runRoster(options: options)
            return
        }
        let config = FightSimBatchConfig(
            batchSeed: options.batchSeed,
            matchCount: options.matchCount,
            ticksPerMatch: options.ticksPerMatch,
            p1Difficulty: options.p1Difficulty,
            p2Difficulty: options.p2Difficulty
        )
        let report = AIMatchDriver.runBatch(config)
        try writeJSON(report, options: options, pretty: false)
    }

    private static func runRoster(options: Options) throws {
        guard let p1 = options.p1FighterID, let p2 = options.p2FighterID else {
            throw CLIError.missingFighter
        }
        let config = RosterMatchDriver.Config(
            p1FighterID: p1,
            p2FighterID: p2,
            stageID: options.stageID,
            seedStart: options.seedStart,
            seedEnd: options.seedEnd,
            p1Difficulty: options.p1Difficulty,
            p2Difficulty: options.p2Difficulty,
            tickLimit: options.rosterTickLimit
        )
        if options.progress {
            FightSimStdio.writeError(
                "roster \(p1) vs \(p2) seeds \(options.seedStart)...\(options.seedEnd) \(options.stageID)"
            )
        }
        let report = try RosterMatchDriver.run(config)
        if options.progress {
            FightSimStdio.writeError(
                "done wins \(report.p1Wins)-\(report.p2Wins) draws \(report.draws) throws \(report.p1ThrowCount)/\(report.p2ThrowCount) dist \(String(format: "%.2f", report.meanEngagementDistancePx))px"
            )
        }
        try writeJSON(report, options: options, pretty: true)
    }

    private static func writeJSON<T: Encodable>(_ value: T, options: Options, pretty: Bool) throws {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let data = try encoder.encode(value)
        guard var text = String(data: data, encoding: .utf8) else {
            throw CLIError.encodeFailed
        }
        if !text.hasSuffix("\n") {
            text.append("\n")
        }
        if let path = options.jsonOutputPath {
            try text.write(toFile: path, atomically: true, encoding: .utf8)
        }
        if options.jsonToStdout {
            print(text)
        }
    }

    private enum CLIError: Error, CustomStringConvertible {
        case encodeFailed
        case missingFighter

        var description: String {
            switch self {
            case .encodeFailed:
                return "could not encode JSON"
            case .missingFighter:
                return "roster mode requires --p1-fighter and --p2-fighter"
            }
        }
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

        Greybox batch (unchanged):
          swift run FightSim [--seed N|0xN] [--batch N] [--ticks N] [--p1 easy|normal|hard] [--p2 easy|normal|hard] [--json-out path]

        Shipped roster (full match, stops at matchOver or --tick-limit):
          swift run FightSim --p1-fighter kestrel --p2-fighter bruno --seed-start 1 --seed-end 100 --p1 hard --p2 hard --stage stage1 --json-out report.json --quiet

        Defaults: greybox batch 1, ticks \(MatchRules.roundTickLimit), both normal, JSON on stdout.
        Roster default tick limit is two full 5-round budgets so hitstop can finish a match.
        """
        print(usage)
    }
}