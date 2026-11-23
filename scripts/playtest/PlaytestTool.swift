// Playtest helper for driving ArcadeFighter on a local Mac.
// Built by scripts/playtest/lib.sh into build/playtest/bin/playtest. macOS only.
//
//   playtest permissions                 report Accessibility / Screen Recording status
//   playtest request-permissions         trigger the macOS permission prompts
//   playtest window-id <pid>             CGWindowID of the game window (for screencapture -l)
//   playtest front-pid                   pids owning the frontmost window and keyboard focus
//   playtest activate <pid>              bring the game to the front, verify it took
//   playtest keys <pid> <step>...        send keyboard input (see STEP SYNTAX)
//
// STEP SYNTAX (key names below; durations in ms; one game tick is ~16.7 ms)
//   tap:KEY[:MS]              press KEY, hold MS (default 60), release
//   hold:KEY[+KEY...]:MS      press all keys together, hold MS, release all
//   seq:G1,G2,...:MS          motion input: each group (KEY+KEY) held MS, rolling into the next
//                             e.g. P1 facing right quarter-circle-forward + LP: seq:s,s+d,d+f:50
//   press:KEY / release:KEY   low-level, for long holds across other steps
//   wait:MS                   do nothing for MS
//   shot:LABEL                screenshot the game window now (held keys stay held), into
//                             $PLAYTEST_SHOT_DIR; e.g. press:s wait:250 shot:crouch release:s
//
// `keys` releases anything still held when it exits.
//
// Every step first checks that <pid> owns the frontmost window and aborts (releasing held keys)
// if not, so keystrokes never land in the terminal or another app.

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// Virtual key codes. Mirrors AppLogic MacVirtualKeyCode and MenuKeyboardKeyCode.
let keyTable: [String: CGKeyCode] = [
    // P1 (also menu navigation): WASD move, F/G/H/J = LP/HP/LK/HK
    "w": 13, "a": 0, "s": 1, "d": 2,
    "f": 3, "g": 5, "h": 4, "j": 38,
    // P2: arrows move; numpad 4/5/1/2 or I/O/K/L = LP/HP/LK/HK
    "up": 126, "down": 125, "left": 123, "right": 124,
    "kp4": 86, "kp5": 87, "kp1": 83, "kp2": 84,
    "i": 34, "o": 31, "k": 40, "l": 37,
    // Menu / system
    "return": 36, "enter": 36, "space": 49, "esc": 53, "p": 35,
]

var heldKeys: Set<CGKeyCode> = []
let eventSource = CGEventSource(stateID: .hidSystemState)
let startTime = Date()

func say(_ text: String) {
    let t = String(format: "%7.3f", Date().timeIntervalSince(startTime))
    print("[+\(t)s] \(text)")
    fflush(stdout)
}

func flags(for code: CGKeyCode) -> CGEventFlags {
    switch code {
    case 123...126: return [.maskNumericPad, .maskSecondaryFn]
    case 65...92: return [.maskNumericPad]
    default: return []
    }
}

func post(_ code: CGKeyCode, down: Bool) {
    guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: down) else {
        fail("could not create key event for code \(code)")
    }
    event.flags = flags(for: code)
    event.post(tap: .cghidEventTap)
    if down { heldKeys.insert(code) } else { heldKeys.remove(code) }
}

func releaseAll() {
    for code in heldKeys { post(code, down: false) }
}

func fail(_ message: String) -> Never {
    releaseAll()
    FileHandle.standardError.write(Data("playtest: \(message)\n".utf8))
    exit(1)
}

func sleepMS(_ ms: Int) {
    if ms > 0 { usleep(useconds_t(ms) * 1000) }
}

func windows() -> [[String: Any]] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    return CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
}

/// Owner of the frontmost layer-0 (normal app) window; the list is ordered front to back.
func frontWindowOwnerPID() -> pid_t? {
    for info in windows() where (info[kCGWindowLayer as String] as? Int) == 0 {
        if let pid = info[kCGWindowOwnerPID as String] as? Int { return pid_t(pid) }
    }
    return nil
}

/// App holding keyboard focus. Keys posted to the HID tap go here, whatever window is on top:
/// a system alert (UserNotificationCenter) can take focus without covering the game window.
/// Pump the run loop so NSWorkspace's cached value is current in this CLI process.
func focusedAppPID() -> pid_t? {
    RunLoop.current.run(until: Date())
    return NSWorkspace.shared.frontmostApplication?.processIdentifier
}

/// True only when the game owns both the top window and keyboard focus.
func gameHasFocus(_ pid: pid_t) -> Bool {
    frontWindowOwnerPID() == pid && focusedAppPID() == pid
}

func gameWindowID(pid: pid_t) -> Int? {
    var best: (id: Int, area: Double)?
    for info in windows() {
        guard (info[kCGWindowOwnerPID as String] as? Int).map({ pid_t($0) }) == pid,
              (info[kCGWindowLayer as String] as? Int) == 0,
              let id = info[kCGWindowNumber as String] as? Int,
              let bounds = info[kCGWindowBounds as String] as? [String: Double]
        else { continue }
        let area = (bounds["Width"] ?? 0) * (bounds["Height"] ?? 0)
        if best == nil || area > best!.area { best = (id, area) }
    }
    return best?.id
}

func activate(pid: pid_t) -> Bool {
    if gameHasFocus(pid) { return true }
    NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    for _ in 0..<20 {
        if gameHasFocus(pid) { return true }
        sleepMS(50)
    }
    // macOS 14+ ignores activateIgnoringOtherApps from a CLI; ask System Events instead.
    let script = "tell application \"System Events\" to set frontmost of (first process whose unix id is \(pid)) to true"
    let osa = Process()
    osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    osa.arguments = ["-e", script]
    try? osa.run()
    osa.waitUntilExit()
    for _ in 0..<20 {
        if gameHasFocus(pid) { return true }
        sleepMS(50)
    }
    return false
}

func requireFront(_ pid: pid_t) {
    guard gameHasFocus(pid) else {
        let focused = focusedAppPID().flatMap { NSRunningApplication(processIdentifier: $0)?.localizedName } ?? "unknown"
        fail("game (pid \(pid)) does not have keyboard focus (focused app: \(focused)); aborting so keys don't go elsewhere. Run: playtest activate \(pid)")
    }
}

func keyCode(_ name: String) -> CGKeyCode {
    guard let code = keyTable[name.lowercased()] else {
        fail("unknown key '\(name)'. Known: \(keyTable.keys.sorted().joined(separator: " "))")
    }
    return code
}

func keyGroup(_ text: String) -> [CGKeyCode] {
    text.split(separator: "+").map { keyCode(String($0)) }
}

func ms(_ text: Substring?, default value: Int? = nil) -> Int {
    if let text, let parsed = Int(text), parsed >= 0 { return parsed }
    if let value { return value }
    fail("expected a duration in ms, got '\(text ?? "")'")
}

func runStep(_ step: String, pid: pid_t) {
    let parts = step.split(separator: ":", omittingEmptySubsequences: false)
    guard let verb = parts.first else { return }
    if verb != "wait" { requireFront(pid) }
    switch verb {
    case "tap":
        guard parts.count >= 2 else { fail("tap needs a key: \(step)") }
        let code = keyCode(String(parts[1]))
        let hold = ms(parts.count > 2 ? parts[2] : nil, default: 60)
        say("tap \(parts[1]) \(hold)ms")
        post(code, down: true); sleepMS(hold); post(code, down: false)
    case "hold":
        guard parts.count == 3 else { fail("hold needs KEY[+KEY]:MS: \(step)") }
        let codes = keyGroup(String(parts[1]))
        let hold = ms(parts[2])
        say("hold \(parts[1]) \(hold)ms")
        codes.forEach { post($0, down: true) }
        sleepMS(hold)
        codes.forEach { post($0, down: false) }
    case "seq":
        guard parts.count == 3 else { fail("seq needs G1,G2,...:MS: \(step)") }
        let groups = parts[1].split(separator: ",").map { Set(keyGroup(String($0))) }
        let each = ms(parts[2])
        say("seq \(parts[1]) \(each)ms/step")
        var current: Set<CGKeyCode> = []
        for group in groups {
            requireFront(pid)
            current.subtracting(group).forEach { post($0, down: false) }
            group.subtracting(current).forEach { post($0, down: true) }
            current = group
            sleepMS(each)
        }
        current.forEach { post($0, down: false) }
    case "press":
        guard parts.count == 2 else { fail("press needs a key: \(step)") }
        say("press \(parts[1])")
        post(keyCode(String(parts[1])), down: true)
    case "release":
        guard parts.count == 2 else { fail("release needs a key: \(step)") }
        say("release \(parts[1])")
        post(keyCode(String(parts[1])), down: false)
    case "wait":
        let wait = ms(parts.count > 1 ? parts[1] : nil)
        say("wait \(wait)ms")
        sleepMS(wait)
    case "shot":
        let label = parts.count > 1 ? String(parts[1]) : "shot"
        say("shot \(captureWindow(pid: pid, label: label))")
        return // no settle delay: held keys stay held across a shot
    default:
        fail("unknown step '\(step)'")
    }
    sleepMS(20) // let the 60 Hz tick sample the release before the next step
}

/// Screenshot just the game window into $PLAYTEST_SHOT_DIR (default: current directory).
func captureWindow(pid: pid_t, label: String) -> String {
    guard let id = gameWindowID(pid: pid) else { fail("no window to capture for pid \(pid)") }
    let dir = ProcessInfo.processInfo.environment["PLAYTEST_SHOT_DIR"] ?? FileManager.default.currentDirectoryPath
    let stamp = DateFormatter()
    stamp.dateFormat = "yyyyMMdd-HHmmss-SSS"
    let path = "\(dir)/\(stamp.string(from: Date()))-\(label).png"
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-o", "-l", String(id), path]
    do { try capture.run() } catch { fail("screencapture failed: \(error)") }
    capture.waitUntilExit()
    guard capture.terminationStatus == 0 else { fail("screencapture exited \(capture.terminationStatus)") }
    return path
}

func pidArg(_ args: [String], _ index: Int) -> pid_t {
    guard index < args.count, let pid = pid_t(args[index]) else { fail("expected a pid argument") }
    return pid
}

signal(SIGINT) { _ in releaseAll(); exit(130) }
signal(SIGTERM) { _ in releaseAll(); exit(143) }

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "permissions":
    let ax = AXIsProcessTrusted()
    let screen = CGPreflightScreenCaptureAccess()
    print("accessibility=\(ax)")
    print("screen_recording=\(screen)")
    if !ax { print("-> Grant Accessibility to your terminal app: System Settings > Privacy & Security > Accessibility") }
    if !screen { print("-> Grant Screen Recording to your terminal app: System Settings > Privacy & Security > Screen & System Audio Recording") }
    exit(ax && screen ? 0 : 2)
case "request-permissions":
    // Literal value of kAXTrustedCheckOptionPrompt (its Swift import type varies by SDK).
    _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    _ = CGRequestScreenCaptureAccess()
    print("Prompts requested. After granting, fully quit and reopen the terminal app, then rerun: playtest permissions")
case "window-id":
    guard let id = gameWindowID(pid: pidArg(args, 2)) else { fail("no on-screen window for that pid") }
    print(id)
case "front-pid":
    guard let pid = frontWindowOwnerPID() else { fail("no frontmost window") }
    print(pid) // stdout stays a bare pid for scripts; the focus detail goes to stderr
    FileHandle.standardError.write(Data("window=\(pid) focused=\(focusedAppPID().map(String.init) ?? "none")\n".utf8))
case "activate":
    let pid = pidArg(args, 2)
    guard activate(pid: pid) else { fail("could not bring pid \(pid) to the front; click the game window once and retry") }
    print("frontmost=\(pid)")
case "keys":
    let pid = pidArg(args, 2)
    guard AXIsProcessTrusted() else { fail("Accessibility permission missing for this terminal; run: playtest permissions") }
    guard activate(pid: pid) else { fail("could not bring pid \(pid) to the front") }
    sleepMS(150)
    for step in args.dropFirst(3) { runStep(step, pid: pid) }
    releaseAll()
default:
    print("usage: playtest permissions|request-permissions|window-id PID|front-pid|activate PID|keys PID STEP...")
    exit(64)
}
