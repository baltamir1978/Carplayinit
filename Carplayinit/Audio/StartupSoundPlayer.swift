import AVFoundation

/// Plays the chosen chime, in the app and from the background watcher alike.
@MainActor
final class StartupSoundPlayer: NSObject, ObservableObject {
    static let shared = StartupSoundPlayer()

    @Published private(set) var playingSoundID: String?

    /// Marca la escucha de un fragmento en el recortador, que no es un sonido de la lista.
    static let excerptID = "__excerpt__"

    private var player: AVAudioPlayer?
    /// Corta el fragmento a su hora. Vive aquí y no en la vista a propósito: una
    /// `View` es una struct que SwiftUI rehace y descarta cuando le conviene, y un
    /// temporizador colgado de su estado se queda sin quien lo pare — que es como
    /// un fragmento de tres segundos acababa sonando el archivo entero.
    private var stopTask: Task<Void, Never>?

    /// Plays whatever the user picked as their startup sound.
    func playSelected() {
        guard let id = SharedStore.selectedSoundID,
              let sound = SoundLibrary.shared.soundOrBundled(id: id) else { return }
        play(sound)
    }

    func play(_ sound: StartupSound) {
        guard let url = sound.url else {
            NSLog("[Carplayinit] sin ruta para \(sound.id)")
            return
        }
        // A synthesised chime whose file went missing can just be made again.
        if !FileManager.default.fileExists(atPath: url.path),
           let recipe = ChimeRecipes.recipe(id: sound.id) {
            _ = try? ChimeSynth.file(for: recipe)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            NSLog("[Carplayinit] falta el audio de \(sound.id)")
            return
        }

        // Configuring the session and playing are two separate failures: a session
        // that refuses to configure is no reason not to try to make a sound.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            NSLog("[Carplayinit] audio session error: \(error)")
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            // Clips are normalised to −12 dBFS on import; this is the user's trim.
            player.volume = Float(SharedStore.outputVolume)
            player.prepareToPlay()
            player.play()
            self.player = player
            playingSoundID = sound.id
        } catch {
            NSLog("[Carplayinit] playback error: \(error)")
        }
    }

    /// Escucha `seconds` a partir de `start`, para la vista previa del recorte.
    func playExcerpt(of url: URL, from start: TimeInterval, seconds: TimeInterval) {
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            NSLog("[Carplayinit] audio session error: \(error)")
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.currentTime = start
            player.play()
            self.player = player
            playingSoundID = Self.excerptID
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            NSLog("[Carplayinit] excerpt error: \(error)")
        }
    }

    var isPlayingExcerpt: Bool { playingSoundID == Self.excerptID }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
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
