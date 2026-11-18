import FightCore
import Foundation

public enum FighterCommandLoader {
    public enum LoadError: Error, Equatable, CustomStringConvertible {
        case unreadable(String)
        case unknownMotion(String, String)
        case unknownButton(String, String)

        public var description: String {
            switch self {
            case .unreadable(let id):
                return "could not read commands for \(id)"
            case .unknownMotion(let moveID, let motion):
                return "\(moveID) has unknown motion \(motion)"
            case .unknownButton(let moveID, let button):
                return "\(moveID) has unknown button \(button)"
            }
        }
    }

    public static func load(id: String, fromFile file: String = #filePath) throws -> [MoveCommand] {
        let url = ContentPaths.fighterDirectory(id, fromFile: file).appendingPathComponent("fighter.json")
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LoadError.unreadable(id)
        }
        let fileJSON = try JSONDecoder().decode(CommandFile.self, from: data)
        return try commands(fighterID: fileJSON.id, moves: fileJSON.moves)
    }

    static func commands(fighterID: String, moves: [CommandFile.Move]) throws -> [MoveCommand] {
        var rows: [MoveCommand] = []
        for move in moves {
            let motion = try motionPattern(move)
            let masks = try buttonMasks(move)
            for mask in masks {
                rows.append(MoveCommand(fighterID: fighterID, moveID: move.id, motion: motion, buttons: mask))
            }
        }
        return rows
    }

    private static func motionPattern(_ move: CommandFile.Move) throws -> MotionPattern? {
        if move.input.stance == "throw" { return nil }
        guard let raw = move.input.motion else { return nil }
        switch raw {
        case "236":
            return .qcf236
        case "214":
            return .qcb214
        case "623":
            return .dp623
        case "236236":
            return .super236236
        default:
            throw LoadError.unknownMotion(move.id, raw)
        }
    }

    private static func buttonMasks(_ move: CommandFile.Move) throws -> [UInt8] {
        if move.input.stance == "throw" {
            return [MoveCommandTable.bit(.lightPunch) | MoveCommandTable.bit(.lightKick)]
        }
        guard let button = move.input.button else { return [] }
        switch button {
        case "LP":
            return [MoveCommandTable.bit(.lightPunch)]
        case "HP":
            return [MoveCommandTable.bit(.heavyPunch)]
        case "LK":
            return [MoveCommandTable.bit(.lightKick)]
        case "HK":
            return [MoveCommandTable.bit(.heavyKick)]
        case "P":
            return [MoveCommandTable.bit(.lightPunch), MoveCommandTable.bit(.heavyPunch)]
        case "K":
            return [MoveCommandTable.bit(.lightKick), MoveCommandTable.bit(.heavyKick)]
        case "LP+LK":
            return [MoveCommandTable.bit(.lightPunch) | MoveCommandTable.bit(.lightKick)]
        default:
            throw LoadError.unknownButton(move.id, button)
        }
    }
}

struct CommandFile: Decodable {
    struct Move: Decodable {
        struct Input: Decodable {
            var button: String?
            var stance: String?
            var motion: String?
        }

        var id: String
        var input: Input
    }

    var id: String
    var moves: [Move]
}
