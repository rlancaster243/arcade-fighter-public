/// Shared timing and gameplay constants for fighter stepping (integer-only).
public enum FighterConstants {
    public static let groundY: Int32 = 0
    public static let jumpStartupTicks: Int32 = 4
    public static let landingTicks: Int32 = 3
    public static let throwTechWindowTicks: Int32 = 7
    public static let throwRangeRaw: Int32 = 48 * Fixed.scale
    public static let normalRecoveryCancelFrames: Int32 = 2
    public static let defaultGetupTicks: Int32 = 11
    public static let defaultKnockdownTicks: Int32 = 21
    public static let builtinJumpCommand = "__jump__"
}