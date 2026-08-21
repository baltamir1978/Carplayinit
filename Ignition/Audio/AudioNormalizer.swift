import AVFoundation

/// Prepares imported audio for the car: trims to a sane length, normalises the peak
/// to −12 dBFS and writes an `.m4a` into the shared container.
///
/// −12 dBFS is not arbitrary: head units play system chimes noticeably louder than
/// music, so a clip mastered at 0 dBFS is a fright at seven in the morning.
enum AudioNormalizer {
    static let targetPeakDB: Float = -12
    static let maxDuration: TimeInterval = 10

    enum ImportError: LocalizedError {
        case unreadable
        case emptyAudio
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .unreadable:            return "No se pudo leer el archivo de audio."
            case .emptyAudio:            return "El archivo no contiene audio."
            case .exportFailed(let why): return "No se pudo convertir el audio: \(why)"
            }
        }
    }

    /// Imports `sourceURL`, returning a `StartupSound` backed by a normalised copy.
    static func importSound(from sourceURL: URL, name: String) async throws -> StartupSound {
        let needsScope = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsScope { sourceURL.stopAccessingSecurityScopedResource() } }

        let asset = AVURLAsset(url: sourceURL)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            throw ImportError.emptyAudio
        }
        let duration = try await asset.load(.duration)
        let trimmed = min(CMTimeGetSeconds(duration), maxDuration)

        let gain = try await peakGain(for: asset, track: track)

        let composition = AVMutableComposition()
        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio,
                                                           preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ImportError.unreadable
        }
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: trimmed, preferredTimescale: 600))
        try audioTrack.insertTimeRange(range, of: track, at: .zero)

        // A single volume ramp is enough — we only ever scale the whole clip.
        let params = AVMutableAudioMixInputParameters(track: audioTrack)
        params.setVolume(gain, at: .zero)
        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]

        let fileName = "\(UUID().uuidString).m4a"
        let destination = SharedStore.soundsDirectory.appendingPathComponent(fileName)
        let temporary = try await export(composition, mix: mix)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)

        return StartupSound(id: UUID().uuidString, name: name, packID: SoundLibrary.importedPackID,
                            storage: .container, fileName: fileName, duration: trimmed)
    }

    // MARK: - Two-layer mix

    /// Lays `foreground` (a voice, a jingle) over `background` (music), ducking the
    /// music to `backgroundGain` and fading it in and out so the clip does not start
    /// or end on a cut. The result is trimmed, normalised and stored like any import.
    ///
    /// The mix length follows the foreground: the background is looped or cut to fit.
    static func mixSounds(foreground: URL,
                          background: URL,
                          backgroundGain: Float = 0.35,
                          name: String) async throws -> StartupSound {
        let fgScope = foreground.startAccessingSecurityScopedResource()
        let bgScope = background.startAccessingSecurityScopedResource()
        defer {
            if fgScope { foreground.stopAccessingSecurityScopedResource() }
            if bgScope { background.stopAccessingSecurityScopedResource() }
        }

        let fgAsset = AVURLAsset(url: foreground)
        let bgAsset = AVURLAsset(url: background)

        guard let fgTrack = try? await fgAsset.loadTracks(withMediaType: .audio).first,
              let bgTrack = try? await bgAsset.loadTracks(withMediaType: .audio).first else {
            throw ImportError.emptyAudio
        }

        let fgSeconds = min(CMTimeGetSeconds(try await fgAsset.load(.duration)), maxDuration)
        let bgSeconds = CMTimeGetSeconds(try await bgAsset.load(.duration))
        guard fgSeconds > 0, bgSeconds > 0 else { throw ImportError.emptyAudio }

        let total = CMTime(seconds: fgSeconds, preferredTimescale: 600)
        let composition = AVMutableComposition()

        guard let fgComp = composition.addMutableTrack(withMediaType: .audio,
                                                       preferredTrackID: kCMPersistentTrackID_Invalid),
              let bgComp = composition.addMutableTrack(withMediaType: .audio,
                                                       preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ImportError.unreadable
        }

        try fgComp.insertTimeRange(CMTimeRange(start: .zero, duration: total), of: fgTrack, at: .zero)

        // Loop the bed until it covers the foreground.
        var filled = CMTime.zero
        while filled < total {
            let chunk = min(CMTime(seconds: bgSeconds, preferredTimescale: 600), total - filled)
            try bgComp.insertTimeRange(CMTimeRange(start: .zero, duration: chunk), of: bgTrack, at: filled)
            filled = filled + chunk
        }

        let fgParams = AVMutableAudioMixInputParameters(track: fgComp)
        fgParams.setVolume(1, at: .zero)

        let fade = CMTime(seconds: min(0.6, fgSeconds / 4), preferredTimescale: 600)
        let bgParams = AVMutableAudioMixInputParameters(track: bgComp)
        bgParams.setVolumeRamp(fromStartVolume: 0, toEndVolume: backgroundGain,
                               timeRange: CMTimeRange(start: .zero, duration: fade))
        bgParams.setVolume(backgroundGain, at: fade)
        bgParams.setVolumeRamp(fromStartVolume: backgroundGain, toEndVolume: 0,
                               timeRange: CMTimeRange(start: total - fade, duration: fade))

        let mix = AVMutableAudioMix()
        mix.inputParameters = [fgParams, bgParams]

        let mixedURL = try await export(composition, mix: mix)

        // Re-import the mix so it goes through the same −12 dBFS normalisation as
        // everything else; two layers summed can easily clip.
        let sound = try await importSound(from: mixedURL, name: name)
        try? FileManager.default.removeItem(at: mixedURL)
        return sound
    }

    /// Writes a composition to a temporary `.m4a`.
    private static func export(_ composition: AVComposition, mix: AVAudioMix?) async throws -> URL {
        guard let session = AVAssetExportSession(asset: composition,
                                                 presetName: AVAssetExportPresetAppleM4A) else {
            throw ImportError.exportFailed("preset no disponible")
        }
        session.audioMix = mix
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mix-\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: url)
        try await session.export(to: url, as: .m4a)
        return url
    }

    /// Linear gain that puts the loudest sample at `targetPeakDB`, capped so we
    /// never amplify hiss in a very quiet recording by more than 12 dB.
    private static func peakGain(for asset: AVAsset, track: AVAssetTrack) async throws -> Float {
        guard let reader = try? AVAssetReader(asset: asset) else { throw ImportError.unreadable }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        reader.startReading()

        var peak: Float = 0
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var bytes = [Int16](repeating: 0, count: length / 2)
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: &bytes)
            for sample in bytes {
                peak = max(peak, abs(Float(sample) / Float(Int16.max)))
            }
        }
        reader.cancelReading()

        guard peak > 0 else { throw ImportError.emptyAudio }
        let target = pow(10, targetPeakDB / 20)
        return min(target / peak, 4)
    }
}
