import AVFoundation

/// Turns typed text into a startup chime, spoken by the system voices.
///
/// `AVSpeechSynthesizer.write` hands back raw PCM instead of playing it, which is
/// what lets the result go through the same normalising pipeline as any import:
/// trimmed, faded and levelled to −12 dBFS, so a spoken clip does not shout over
/// the chimes it sits next to in the list.
///
/// The voice itself is left exactly as Apple ships it — no pitch shifting, no rate
/// tweaking. Which voice speaks is the user's pick in Ajustes, or one of the
/// installed Spanish voices chosen here.
enum SpeechSynth {
    enum SpeechError: LocalizedError {
        case noVoice
        case emptyRender

        var errorDescription: String? {
            switch self {
            case .noVoice:     return "No hay ninguna voz en español instalada en el iPhone."
            case .emptyRender: return "La voz no generó audio. Prueba con otro texto."
            }
        }
    }

    // MARK: - Voice picking

    /// Every Spanish voice installed, by name — what the picker offers.
    static func spanishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("es") }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The voice the user pinned, if any. Empty means the one the system already
    /// uses for Spanish, whichever that is.
    static var preferredIdentifier: String? {
        get { UserDefaults.standard.string(forKey: "speech_voice") }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: "speech_voice")
            } else {
                UserDefaults.standard.removeObject(forKey: "speech_voice")
            }
        }
    }

    /// The voice that will actually talk: the pinned one, or the system's own for
    /// Spanish. `nil` only when the phone has no Spanish voice at all.
    static func voice(for identifier: String? = preferredIdentifier) -> AVSpeechSynthesisVoice? {
        if let identifier, let pinned = AVSpeechSynthesisVoice(identifier: identifier) {
            return pinned
        }
        return AVSpeechSynthesisVoice(language: nil) ?? spanishVoices().first
    }

    /// Clears what the two-voice build left behind: it pinned a voice per gender,
    /// under keys nobody reads any more. Cheap and self-limiting — once the keys
    /// are gone the guard makes every later launch a no-op.
    static func discardLegacyPreferences() {
        let defaults = UserDefaults.standard
        for key in ["voice_masculine", "voice_feminine"]
        where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
        }
    }

    /// "Paulina · es-MX · Mejorada" — so it is never a mystery which voice is talking.
    static func describe(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium:  quality = "Premium"
        case .enhanced: quality = "Mejorada"
        default:        quality = "Compacta"
        }
        return "\(voice.name) · \(voice.language) · \(quality)"
    }

    static func utterance(text: String, identifier: String? = preferredIdentifier) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: identifier)
        // A beat of silence at the end: without it the last word can get clipped by
        // the fade the normaliser puts on the tail.
        utterance.postUtteranceDelay = 0.15
        return utterance
    }

    // MARK: - Rendering

    /// Renders the text to a temporary `.caf`. The caller owns the file.
    static func render(text: String, identifier: String? = preferredIdentifier) async throws -> URL {
        guard voice(for: identifier) != nil else { throw SpeechError.noVoice }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-\(UUID().uuidString).caf")
        let synthesizer = AVSpeechSynthesizer()
        let writer = Writer(url: url)

        return try await withCheckedThrowingContinuation { continuation in
            synthesizer.write(utterance(text: text, identifier: identifier)) { buffer in
                // `synthesizer` is captured so it outlives the callbacks; letting it
                // go early stops the render halfway through the sentence.
                _ = synthesizer
                writer.receive(buffer) { continuation.resume(with: $0) }
            }
        }
    }

    /// Collects the callback's buffers into a file.
    ///
    /// `@unchecked Sendable` with a lock: the callbacks arrive on the synthesiser's
    /// own queue, and the last one — the empty buffer that means "done" — is what
    /// resumes the continuation, exactly once.
    private final class Writer: @unchecked Sendable {
        private let url: URL
        private let lock = NSLock()
        private var file: AVAudioFile?
        private var frames: AVAudioFrameCount = 0
        private var settled = false

        init(url: URL) { self.url = url }

        func receive(_ buffer: AVAudioBuffer, finish: (Result<URL, Error>) -> Void) {
            lock.lock()
            defer { lock.unlock() }
            guard !settled, let pcm = buffer as? AVAudioPCMBuffer else { return }

            guard pcm.frameLength > 0 else {
                settled = true
                file = nil          // closes the file
                finish(frames > 0 ? .success(url) : .failure(SpeechError.emptyRender))
                return
            }

            do {
                if file == nil {
                    file = try AVAudioFile(forWriting: url,
                                           settings: pcm.format.settings,
                                           commonFormat: pcm.format.commonFormat,
                                           interleaved: pcm.format.isInterleaved)
                }
                try file?.write(from: pcm)
                frames += pcm.frameLength
            } catch {
                settled = true
                file = nil
                finish(.failure(error))
            }
        }
    }
}
