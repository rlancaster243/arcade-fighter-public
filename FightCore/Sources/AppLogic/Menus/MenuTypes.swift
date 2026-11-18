import FightCore

/// Logical menu screens driven by `MenuReducer`.
public enum MenuScreen: Sendable, Equatable, Hashable, Codable {
    case title
    case mainMenu
    case arcadeLadder
    case versusSetup
    case characterSelect(CharacterSelectContext)
    case inMatch(MatchSetup)
    case matchPaused(MatchSetup)
    case result(MatchResultSummary)
    case settings(SettingsPane)
    case rematchPrompt(MatchSetup)
}

public enum CharacterSelectContext: Sendable, Equatable, Hashable, Codable {
    case arcade(playerFighter: FighterPick)
    case versus(selecting: PlayerSlot, p1: FighterPick?, p2: FighterPick?)
}

public struct FighterPick: Sendable, Equatable, Hashable, Codable {
    public var rosterIndex: Int
    public var id: String

    public init(rosterIndex: Int, id: String) {
        self.rosterIndex = rosterIndex
        self.id = id
    }
}

public enum MatchMode: Sendable, Equatable, Hashable, Codable {
    case arcade
    case versus
}

public struct MatchSetup: Sendable, Equatable, Hashable, Codable {
    public var mode: MatchMode
    public var p1: FighterPick
    public var p2: FighterPick
    public var stageIndex: Int
    public var arcadeRun: ArcadeRunState?
    public var difficulty: Difficulty

    public init(
        mode: MatchMode,
        p1: FighterPick,
        p2: FighterPick,
        stageIndex: Int = 0,
        arcadeRun: ArcadeRunState? = nil,
        difficulty: Difficulty = .normal
    ) {
        self.mode = mode
        self.p1 = p1
        self.p2 = p2
        self.stageIndex = stageIndex
        self.arcadeRun = arcadeRun
        self.difficulty = difficulty
    }
}

public struct ArcadeRunState: Sendable, Equatable, Hashable, Codable {
  public static let ladderLength = 3

    public var opponentIndex: Int
    public var victories: Int

    public init(opponentIndex: Int = 0, victories: Int = 0) {
        self.opponentIndex = opponentIndex
        self.victories = victories
    }

    public var isComplete: Bool {
        opponentIndex >= Self.ladderLength
    }

    public func difficulty(forOpponentAt index: Int) -> Difficulty {
        switch index {
        case 0:
            return .easy
        case 1:
            return .normal
        default:
            return .hard
        }
    }

    public var currentDifficulty: Difficulty {
        difficulty(forOpponentAt: opponentIndex)
    }
}

public struct MatchResultSummary: Sendable, Equatable, Hashable, Codable {
    public var setup: MatchSetup
    public var winner: PlayerSlot?
    public var p1RoundsWon: Int32
    public var p2RoundsWon: Int32

    public init(
        setup: MatchSetup,
        winner: PlayerSlot?,
        p1RoundsWon: Int32,
        p2RoundsWon: Int32
    ) {
        self.setup = setup
        self.winner = winner
        self.p1RoundsWon = p1RoundsWon
        self.p2RoundsWon = p2RoundsWon
    }
}

public enum SettingsPane: Sendable, Equatable, Hashable, Codable, CaseIterable {
    case display
    case audio
}

public struct DisplayPreferences: Sendable, Equatable, Hashable, Codable {
    public static let designWidth = 384
    public static let designHeight = 216

    public var wantsFullscreen: Bool
    public var windowIntegerScale: Int

    public init(wantsFullscreen: Bool = false, windowIntegerScale: Int = 2) {
        self.wantsFullscreen = wantsFullscreen
        self.windowIntegerScale = max(1, windowIntegerScale)
    }
}

public struct AudioPreferences: Sendable, Equatable, Hashable, Codable {
    public var masterVolumePermille: Int

    public init(masterVolumePermille: Int = 1000) {
        self.masterVolumePermille = min(1000, max(0, masterVolumePermille))
    }
}

public struct AppPreferences: Sendable, Equatable, Hashable, Codable {
    public var display: DisplayPreferences
    public var audio: AudioPreferences

    public init(display: DisplayPreferences = DisplayPreferences(), audio: AudioPreferences = AudioPreferences()) {
        self.display = display
        self.audio = audio
    }
}