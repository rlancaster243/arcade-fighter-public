import FightCore

public struct MenuShellState: Sendable, Equatable, Codable {
    public var screen: MenuScreen
    public var preferences: AppPreferences
    public var cursor: Int
    public var settingsPane: SettingsPane
    public var characterCursor: Int
    public var requestedQuit: Bool

    public init(
        screen: MenuScreen = .title,
        preferences: AppPreferences = AppPreferences(),
        cursor: Int = 0,
        settingsPane: SettingsPane = .display,
        characterCursor: Int = 0,
        requestedQuit: Bool = false
    ) {
        self.screen = screen
        self.preferences = preferences
        self.cursor = cursor
        self.settingsPane = settingsPane
        self.characterCursor = characterCursor
        self.requestedQuit = requestedQuit
    }

    public static let initial = MenuShellState()

    public enum MainMenuItem: Int, CaseIterable, Sendable {
        case arcade = 0
        case versus = 1
        case settings = 2
        case quit = 3

        public var label: String {
            switch self {
            case .arcade: return "Arcade"
            case .versus: return "Versus"
            case .settings: return "Settings"
            case .quit: return "Quit"
            }
        }
    }

    public enum ResultMenuItem: Int, CaseIterable, Sendable {
        case rematch = 0
        case characterSelect = 1
        case mainMenu = 2

        public func label(for summary: MatchResultSummary) -> String {
            switch self {
            case .rematch:
                if summary.setup.mode == .arcade,
                   summary.winner == .p1,
                   let run = summary.setup.arcadeRun,
                   !run.isComplete
                {
                    return "Next Opponent"
                }
                return "Rematch"
            case .characterSelect: return "Character Select"
            case .mainMenu: return "Main Menu"
            }
        }
    }

    public enum SettingsRow: Int, CaseIterable, Sendable {
        case fullscreen = 0
        case windowScale = 1
        case volume = 2
        case back = 3
    }
}