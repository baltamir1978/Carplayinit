import AVFoundation
import Combine
import UIKit

/// Detects when the phone becomes attached to the car and fires the startup chime.
///
/// There is no public API to replace CarPlay's own connection chime — Apple's plays
/// first, always. What we *can* do is notice the audio route turning into a car and
/// play our clip right behind it. Two things make that reliable:
///
/// 1. `UIBackgroundModes: audio`, so the process may keep running while parked in
///    the background;
/// 2. an optional silent keep-alive loop that holds the audio session active, which
///    is what keeps us alive long enough to *hear* the route change hours later.
///
/// The keep-alive costs battery and is the part App Review is most likely to push
/// back on, hence `keepAliveEnabled` — with it off the app still works whenever it
/// happens to be running, and the Shortcuts automation covers the rest.
@MainActor
final class CarConnectionWatcher: ObservableObject {
    static let shared = CarConnectionWatcher()

    @Published private(set) var isConnectedToCar = false
    @Published private(set) var lastConnectionDate: Date?
    @Published private(set) var currentRouteName: String = ""

    /// Holds the audio session alive in the background. See the note above.
    @Published var keepAliveEnabled: Bool {
        didSet {
            UserDefaults.standard.set(keepAliveEnabled, forKey: "keep_alive_enabled")
            keepAliveEnabled ? startKeepAlive() : stopKeepAlive()
        }
    }

    private var keepAlivePlayer: AVAudioPlayer?
    private var observers: [NSObjectProtocol] = []
    /// Route changes arrive in bursts while a car handshakes; ignore repeats.
    private var lastFireDate: Date?
    private let debounce: TimeInterval = 20

    private init() {
        keepAliveEnabled = UserDefaults.standard.bool(forKey: "keep_alive_enabled")
    }

    // MARK: - Lifecycle

    func start() {
        configureSession()
        isConnectedToCar = Self.routeIsCar()
        currentRouteName = Self.routeDescription()

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: nil, queue: .main) { [weak self] note in
            // Unwrap here: a `Notification` is not Sendable, a raw value is.
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated { self?.handleRouteChange(reason: reason) }
        })
        // An interruption (a call, Siri) can leave the session deactivated; re-arm.
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated { self?.handleInterruption(type: type) }
        })

        if keepAliveEnabled { startKeepAlive() }
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        stopKeepAlive()
    }

    // MARK: - Route handling

    private func handleRouteChange(reason reasonValue: UInt?) {
        let wasConnected = isConnectedToCar
        isConnectedToCar = Self.routeIsCar()
        currentRouteName = Self.routeDescription()

        guard SharedStore.startupSoundEnabled else { return }

        let reason = reasonValue.flatMap(AVAudioSession.RouteChangeReason.init) ?? .unknown

        switch (wasConnected, isConnectedToCar) {
        case (false, true) where reason == .newDeviceAvailable || reason == .routeConfigurationChange
                                 || reason == .categoryChange || reason == .override:
            fire(disconnecting: false)
        case (true, false) where SharedStore.playsOnDisconnect:
            fire(disconnecting: true)
        default:
            break
        }
    }

    private func handleInterruption(type typeValue: UInt?) {
        guard let type = typeValue.flatMap(AVAudioSession.InterruptionType.init), type == .ended else { return }
        configureSession()
        if keepAliveEnabled { startKeepAlive() }
    }

    private func fire(disconnecting: Bool) {
        if let last = lastFireDate, Date().timeIntervalSince(last) < debounce { return }
        lastFireDate = Date()
        if !disconnecting { lastConnectionDate = Date() }
        // The head unit needs a beat after the handshake or the first notes are eaten.
        Task {
            try? await Task.sleep(for: .milliseconds(disconnecting ? 100 : 900))
            StartupSoundPlayer.shared.playSelected()
        }
    }

    // MARK: - Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // `.duckOthers` lets the chime sit on top of whatever is already playing
            // instead of stopping the user's music.
            try session.setCategory(.playback, mode: .default,
                                    options: [.duckOthers, .allowBluetoothHFP, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            NSLog("[Carplayinit] audio session error: \(error.localizedDescription)")
        }
    }

    // MARK: - Keep-alive

    private func startKeepAlive() {
        guard keepAlivePlayer == nil else { return }
        let data = Self.silentWAV()
        do {
            let player = try AVAudioPlayer(data: data)
            player.numberOfLoops = -1
            player.volume = 0
            player.play()
            keepAlivePlayer = player
        } catch {
            NSLog("[Carplayinit] keep-alive failed: \(error.localizedDescription)")
        }
    }

    private func stopKeepAlive() {
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
    }

    /// One second of digital silence, synthesised so we ship no filler asset.
    private static func silentWAV(seconds: Int = 1, sampleRate: Int = 8000) -> Data {
        let samples = seconds * sampleRate
        let dataBytes = samples * 2
        var data = Data()
        func append(_ string: String) { data.append(contentsOf: string.utf8) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF");  append32(UInt32(36 + dataBytes)); append("WAVE")
        append("fmt ");  append32(16); append16(1); append16(1)
        append32(UInt32(sampleRate)); append32(UInt32(sampleRate * 2)); append16(2); append16(16)
        append("data");  append32(UInt32(dataBytes))
        data.append(Data(count: dataBytes))
        return data
    }

    // MARK: - Route inspection

    /// True when the current output is a car: CarPlay reports `.carAudio`, most
    /// head units over Bluetooth report A2DP or hands-free.
    static func routeIsCar() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains { output in
            switch output.portType {
            case .carAudio, .bluetoothA2DP, .bluetoothHFP: return true
            default: return false
            }
        }
    }

    static func routeDescription() -> String {
        AVAudioSession.sharedInstance().currentRoute.outputs
            .map(\.portName)
            .joined(separator: ", ")
    }
}
