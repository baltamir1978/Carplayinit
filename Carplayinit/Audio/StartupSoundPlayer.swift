import AVFoundation

/// Plays the chosen chime, in the app and from the background watcher alike.
@MainActor
final class StartupSoundPlayer: NSObject, ObservableObject {
    static let shared = StartupSoundPlayer()

    @Published private(set) var playingSoundID: String?

    private var player: AVAudioPlayer?

    /// Plays whatever the user picked as their startup sound.
    func playSelected() {
        guard let id = SharedStore.selectedSoundID,
              let sound = SoundLibrary.shared.soundOrBundled(id: id) else { return }
        play(sound)
    }

    func play(_ sound: StartupSound) {
        guard let url = sound.url, FileManager.default.fileExists(atPath: url.path) else {
            NSLog("[Carplayinit] missing audio for \(sound.id)")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default,
                                    options: [.duckOthers, .allowBluetoothHFP, .allowBluetoothA2DP])
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            // Clips are normalised to −12 dBFS on import; this is the user's trim.
            player.volume = Float(SharedStore.outputVolume)
            player.prepareToPlay()
            player.play()
            self.player = player
            playingSoundID = sound.id
        } catch {
            NSLog("[Carplayinit] playback error: \(error.localizedDescription)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingSoundID = nil
    }
}

extension StartupSoundPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.playingSoundID = nil
            // Hand the session back so the user's music un-ducks straight away.
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
