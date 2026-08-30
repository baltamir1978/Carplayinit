import AVFoundation

/// Turns typed text into a startup chime, spoken by the system voices.
///
/// `AVSpeechSynthesizer.write` hands back raw PCM instead of playing it, which is
/// what lets the result go through the same normalising pipeline as any import:
/// trimmed, faded and levelled to −12 dBFS, so a spoken clip does not shout over
/// the chimes it sits next to in the list.
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

    /// The two voices offered. Which actual system voice lands here depends on what
    /// the phone has installed, so the pitch does the rest of the work.
    enum VoiceKind: String, CaseIterable, Identifiable {
        case masculine, feminine

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .masculine: return "Masculina"
            case .feminine:  return "Femenina"
            }
        }

        var symbol: String {
            switch self {
            case .masculine: return "person.wave.2.fill"
            case .feminine:  return "person.wave.2"
            }
        }

        fileprivate var gender: AVSpeechSynthesisVoiceGender {
            self == .masculine ? .male : .female
        }

        /// Deep and unhurried for the masculine one; for the feminine, warm rather
        /// than high. Pitch alone past ~1.2 does not read as sultry, it reads as a
        /// chipmunk — what carries that is the slower delivery, so each voice brings
        /// its own rate rather than sharing a neutral one.
        var pitch: Float {
            self == .masculine ? 0.65 : 1.12
        }

        /// Default speed, below the system's 0.5 in both cases: a startup sound is
        /// heard once, over engine noise, and rushing it is what makes it unintelligible.
        var defaultRate: Float {
            self == .masculine ? 0.46 : 0.42
        }

        var character: String {
            switch self {
            case .masculine: return "Grave y pausada."
            case .feminine:  return "Cálida y lenta."
            }
        }
    }

    // MARK: - Voice picking

    /// The best Spanish voice of that gender the phone actually has.
    ///
    /// Quality first, then Castilian over the Latin American variants — and if the
    /// phone has no voice of the asked gender, any Spanish voice will do: the pitch
    /// is what carries the difference anyway.
    static func voice(for kind: VoiceKind) -> AVSpeechSynthesisVoice? {
        let spanish = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("es") }
        guard !spanish.isEmpty else { return nil }
        let matching = spanish.filter { $0.gender == kind.gender }
        return (matching.isEmpty ? spanish : matching).max { rank($0) < rank($1) }
    }

    /// True when the phone has no voice of that gender and the pitch is doing all
    /// the work — worth telling the user, who can install more voices.
    static func isSubstituting(_ kind: VoiceKind) -> Bool {
        let spanish = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("es") }
        return !spanish.isEmpty && !spanish.contains { $0.gender == kind.gender }
    }

    private static func rank(_ voice: AVSpeechSynthesisVoice) -> Int {
        let quality: Int
        switch voice.quality {
        case .premium:  quality = 3
        case .enhanced: quality = 2
        default:        quality = 1
        }
        return quality * 2 + (voice.language == "es-ES" ? 1 : 0)
    }

    static func utterance(text: String, kind: VoiceKind, rate: Float) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: kind)
        utterance.pitchMultiplier = kind.pitch
        utterance.rate = rate
        // A beat of silence at the end: without it the last word can get clipped by
        // the fade the normaliser puts on the tail.
        utterance.postUtteranceDelay = 0.15
        return utterance
    }

    // MARK: - Rendering

    /// Renders the text to a temporary `.caf`. The caller owns the file.
    static func render(text: String, kind: VoiceKind, rate: Float) async throws -> URL {
        guard voice(for: kind) != nil else { throw SpeechError.noVoice }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-\(UUID().uuidString).caf")
        let synthesizer = AVSpeechSynthesizer()
        let writer = Writer(url: url)

        return try await withCheckedThrowingContinuation { continuation in
            synthesizer.write(utterance(text: text, kind: kind, rate: rate)) { buffer in
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
