import Foundation
import FightCore

@main
struct FightSimMain {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let options = FightSimCLI.parseArguments(args) else {
            if !args.isEmpty {
                fputs("Invalid arguments.\n", stderr)
            }
            FightSimCLI.printUsage()
            exit(args.isEmpty ? 0 : 2)
        }
        do {
            try FightSimCLI.run(options: options)
        } catch {
            fputs("FightSim error: \(error)\n", stderr)
            exit(1)
        }
    }
}