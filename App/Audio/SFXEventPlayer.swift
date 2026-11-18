import AppLogic
import FightCore
import Foundation
import Combine

/// Maps `GameEvent`s to manifest clip ids for `SFXPlayer`.
@MainActor
final class SFXEventPlayer: ObservableObject {
    private let player: SFXPlayer
    private var loaded = false
    private(set) var preloadErrorDescription: String?

    init(player: SFXPlayer? = nil) {
        self.player = player ?? SFXPlayer(audioDirectory: SFXContent.audioDirectory())
    }

    @discardableResult
    func preloadIfNeeded() -> [String] {
        guard !loaded else { return [] }
        loaded = true
        var notices: [String] = []
        let root = ContentPaths.repoRoot(fromFile: #filePath)
        do {
            let manifest = try SFXContent.loadManifest(repoRoot: root)
            try player.preload(manifest: manifest)
        } catch {
            preloadErrorDescription = String(describing: error)
            fputs("SFXEventPlayer preload failed: \(error)\n", stderr)
            notices.append("Audio preload failed: \(error.localizedDescription)")
        }
        return notices
    }

    func handle(events: [GameEvent], snapshot: GameSnapshot, metadata: MoveMetadataTable) {
        for event in events {
            guard let clipID = clipID(for: event, snapshot: snapshot, metadata: metadata) else { continue }
            player.play(id: clipID)
        }
    }

    private func clipID(
        for event: GameEvent,
        snapshot: GameSnapshot,
        metadata: MoveMetadataTable
    ) -> String? {
        switch event.kind {
        case .none, .roundEnd:
            return nil
        case .hit, .chip:
            return hitClip(for: event, snapshot: snapshot, metadata: metadata)
        case .block:
            return "block"
        case .throwHit:
            return "throw"
        case .knockdown:
            return "ko"
        case .roundStart:
            return "round_start"
        case .matchWin:
            return "ko"
        case .timeOver:
            return "time_over"
        case .whiff:
            return "whiff"
        }
    }

    private func hitClip(
        for event: GameEvent,
        snapshot: GameSnapshot,
        metadata: MoveMetadataTable
    ) -> String {
        switch metadata.moveInputKindForEvent(event, snapshot: snapshot) {
        case .superMove:
            return "super"
        case .special:
            return "special"
        case .throwMove:
            return "throw"
        case .normal, .none:
            break
        }
        let id = event.moveID.lowercased()
        if id.hasPrefix("hp") || id.hasPrefix("hk") || id.contains("heavy") {
            return "hit_heavy"
        }
        return "hit_light"
    }
}