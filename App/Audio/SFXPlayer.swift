import AVFoundation
import Foundation

/// Plays pre-authored WAV clips from `Content/Audio` via AVFoundation.
@MainActor
final class SFXPlayer: NSObject {
    private var players: [String: AVAudioPlayer] = [:]
    private let audioDirectory: URL

    init(audioDirectory: URL) {
        self.audioDirectory = audioDirectory
        super.init()
    }

    func preload(manifest: SFXManifest) throws {
        var loaded: [String: AVAudioPlayer] = [:]
        for clip in manifest.clips {
            let url = audioDirectory.appendingPathComponent(clip.file)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.numberOfLoops = (clip.loop ?? false) ? -1 : 0
            player.volume = Float(clip.gainQ8) / 256.0
            loaded[clip.id] = player
        }
        players = loaded
    }

    func play(id: String) {
        players[id]?.currentTime = 0
        players[id]?.play()
    }

    func stop(id: String) {
        players[id]?.stop()
    }
}