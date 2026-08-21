import Foundation
import AVFoundation

/// Synthesises the built-in chimes instead of shipping audio files.
///
/// Two reasons: every clip is then ours to license, and a chime that is *generated*
/// can be tuned (pitch, length, brightness) without a trip to a DAW. Rendering is
/// cheap — a second of mono 44.1 kHz — and the result is cached in the App Group so
/// each chime is only built once.
enum ChimeSynth {
    static let sampleRate: Double = 44_100
    /// Same target as imported audio, so switching chimes never changes the level.
    static let targetPeak: Float = 0.251  // −12 dBFS

    // MARK: - Voice description

    enum Waveform {
        case sine
        case triangle
        case square
        case saw
        /// Simple FM — a bell-like timbre without a sample library.
        case fm(ratio: Double, index: Double)
        case noise
    }

    struct Voice {
        var start: Double          // seconds
        var duration: Double
        var frequency: Double
        var endFrequency: Double?  // set for glides/sweeps
        var waveform: Waveform = .sine
        var gain: Double = 1
        var attack: Double = 0.005
        var release: Double = 0.35
    }

    struct Recipe: Identifiable {
        let id: String
        let name: String
        let packID: String
        let voices: [Voice]

        var duration: Double {
            voices.map { $0.start + $0.duration }.max() ?? 0
        }
    }

    // MARK: - Rendering

    /// Returns the cached file for `recipe`, rendering it if needed.
    @discardableResult
    static func file(for recipe: Recipe) throws -> URL {
        let url = SharedStore.soundsDirectory.appendingPathComponent("\(recipe.id).wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let samples = render(recipe)
        try write(samples, to: url)
        return url
    }

    static func render(_ recipe: Recipe) -> [Float] {
        let total = Int((recipe.duration + 0.1) * sampleRate)
        var buffer = [Float](repeating: 0, count: max(total, 1))

        for voice in recipe.voices {
            let startIndex = Int(voice.start * sampleRate)
            let count = Int(voice.duration * sampleRate)
            var phase = 0.0
            var modPhase = 0.0

            for i in 0..<count {
                let index = startIndex + i
                guard index < buffer.count else { break }
                let t = Double(i) / sampleRate
                let progress = voice.duration > 0 ? t / voice.duration : 0

                // Linear glide in the log domain reads as musical, not as a siren.
                let freq: Double
                if let end = voice.endFrequency {
                    freq = voice.frequency * pow(end / voice.frequency, progress)
                } else {
                    freq = voice.frequency
                }

                let increment = freq / sampleRate
                phase += increment
                if phase > 1 { phase -= 1 }

                var sample: Double
                switch voice.waveform {
                case .sine:
                    sample = sin(2 * .pi * phase)
                case .triangle:
                    sample = 4 * abs(phase - 0.5) - 1
                case .square:
                    sample = phase < 0.5 ? 1 : -1
                case .saw:
                    sample = 2 * phase - 1
                case .fm(let ratio, let index):
                    modPhase += increment * ratio
                    if modPhase > 1 { modPhase -= 1 }
                    // The modulation index decays with the note; that decay is what
                    // makes it read as a struck bell rather than a synth pad.
                    let decay = exp(-3 * progress)
                    sample = sin(2 * .pi * phase + index * decay * sin(2 * .pi * modPhase))
                case .noise:
                    sample = Double.random(in: -1...1)
                }

                sample *= envelope(t: t, duration: voice.duration,
                                   attack: voice.attack, release: voice.release) * voice.gain
                buffer[index] += Float(sample)
            }
        }

        normalize(&buffer)
        applyFades(&buffer)
        return buffer
    }

    /// Attack ramp, then an exponential tail — clicks on a car speaker are brutal,
    /// so nothing ever starts or ends on a hard edge.
    private static func envelope(t: Double, duration: Double, attack: Double, release: Double) -> Double {
        let attackGain = attack > 0 ? min(t / attack, 1) : 1
        let remaining = duration - t
        let releaseGain = remaining < release && release > 0
            ? pow(max(remaining, 0) / release, 1.6)
            : 1
        return attackGain * releaseGain
    }

    private static func normalize(_ buffer: inout [Float]) {
        let peak = buffer.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0 else { return }
        let gain = targetPeak / peak
        for i in buffer.indices { buffer[i] *= gain }
    }

    private static func applyFades(_ buffer: inout [Float], milliseconds: Double = 4) {
        let count = min(Int(milliseconds / 1000 * sampleRate), buffer.count / 2)
        guard count > 0 else { return }
        for i in 0..<count {
            let gain = Float(i) / Float(count)
            buffer[i] *= gain
            buffer[buffer.count - 1 - i] *= gain
        }
    }

    // MARK: - WAV output

    /// 16-bit mono PCM. `AVAudioPlayer` reads this straight from the container.
    private static func write(_ samples: [Float], to url: URL) throws {
        var data = Data()
        let byteCount = samples.count * 2

        func append(_ string: String) { data.append(contentsOf: string.utf8) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF"); append32(UInt32(36 + byteCount)); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(1)
        append32(UInt32(sampleRate)); append32(UInt32(sampleRate) * 2); append16(2); append16(16)
        append("data"); append32(UInt32(byteCount))

        for sample in samples {
            let clamped = max(-1, min(1, sample))
            append16(UInt16(bitPattern: Int16(clamped * Float(Int16.max))))
        }
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Helpers

    /// Equal-temperament frequency for a MIDI note number (69 = A4 = 440 Hz).
    static func hz(_ midi: Double) -> Double {
        440 * pow(2, (midi - 69) / 12)
    }
}
