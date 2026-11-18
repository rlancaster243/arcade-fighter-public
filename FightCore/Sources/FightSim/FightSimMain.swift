import Foundation
import FightCore

@main
struct FightSimMain {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let options = FightSimCLI.parseArguments(args) else {
            if !args.isEmpty {
                FightSimStdio.writeError("Invalid arguments.")
            }
            FightSimCLI.printUsage()
            exit(args.isEmpty ? 0 : 2)
        }
        do {
            try FightSimCLI.run(options: options)
        } catch {
            FightSimStdio.writeError("FightSim error: \(error)")
            exit(1)
        }
    }
}