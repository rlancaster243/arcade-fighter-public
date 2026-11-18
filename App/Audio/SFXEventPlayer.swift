import FightCore
import Foundation

/// Maps `GameEvent`s to manifest clip ids for `SFXPlayer`.
@MainActor
final class SFXEventPlayer {
    private let player: SFXPlayer
    private var loaded = false

    init(player: SFXPlayer = SFXPlayer()) {
        self.player = player
    }

    func preloadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        let root = ContentPaths.repoRoot(fromFile: #filePath)
        guard let manifest = try? SFXContent.loadManifest(repoRoot: root) else { return }
        try? player.preload(manifest: manifest)
    }

    func handle(events: [GameEvent]) {
        for event in events {
            guard let clipID = clipID(for: event) else { continue }
            player.play(id: clipID)
        }
    }

    private func clipID(for event: GameEvent) -> String? {
        switch event.kind {
        case .none:
            return nil
        case .hit:
            let id = event.moveID.lowercased()
            if id.hasPrefix("hp") || id.hasPrefix("hk") || id.contains("heavy") {
                return "hit_heavy"
            }
            return "hit_light"
        case .block, .chip:
            return "block"
        case .throwHit:
            return "throw"
        case .knockdown:
            return "ko"
        case .roundStart:
            return "round_start"
        case .roundEnd:
            return nil
        case .matchWin:
            return "ko"
        case .timeOver:
            return "round_start"
        }
    }
}