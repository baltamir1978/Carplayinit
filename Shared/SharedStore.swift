import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Everything the app and its widget extension share, through an App Group.
///
/// Small, structured values live in `UserDefaults`; binaries (car photos, imported
/// chimes) live in the group container so the widget can read them without copying.
enum SharedStore {
    static let suiteName = "group.Altamirano.Ignition"

    private enum Key {
        static let vehicles = "vehicles"
        static let designs = "designs"
        static let selectedSound = "selected_sound_id"
        static let startupSoundEnabled = "startup_sound_enabled"
        static let playOnDisconnect = "play_on_disconnect"
        static let outputVolume = "startup_volume"
        static let importedSounds = "imported_sounds"
    }

    static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    // MARK: - Container

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
            ?? URL.temporaryDirectory
    }

    static var photosDirectory: URL { subdirectory("Photos") }
    static var soundsDirectory: URL { subdirectory("Sounds") }

    private static func subdirectory(_ name: String) -> URL {
        let url = containerURL.appendingPathComponent(name, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    // MARK: - Garage

    static var vehicles: [VehicleProfile] {
        get { decode([VehicleProfile].self, Key.vehicles) ?? [] }
        set { encode(newValue, Key.vehicles) }
    }

    static func vehicle(id: UUID?) -> VehicleProfile? {
        guard let id else { return nil }
        return vehicles.first { $0.id == id }
    }

    // MARK: - Designs

    static var designs: [WidgetDesign] {
        get { decode([WidgetDesign].self, Key.designs) ?? [] }
        set { encode(newValue, Key.designs) }
    }

    static func design(id: UUID?) -> WidgetDesign? {
        let all = designs
        guard let id else { return all.first }
        return all.first { $0.id == id } ?? all.first
    }

    // MARK: - Startup sound

    static var selectedSoundID: String? {
        get { defaults?.string(forKey: Key.selectedSound) }
        set { defaults?.set(newValue, forKey: Key.selectedSound) }
    }

    static var startupSoundEnabled: Bool {
        get { defaults?.object(forKey: Key.startupSoundEnabled) as? Bool ?? true }
        set { defaults?.set(newValue, forKey: Key.startupSoundEnabled) }
    }

    static var playsOnDisconnect: Bool {
        get { defaults?.bool(forKey: Key.playOnDisconnect) ?? false }
        set { defaults?.set(newValue, forKey: Key.playOnDisconnect) }
    }

    /// Playback gain applied on top of the −12 dBFS normalisation, 0…1.
    static var outputVolume: Double {
        get { defaults?.object(forKey: Key.outputVolume) as? Double ?? 0.8 }
        set { defaults?.set(newValue, forKey: Key.outputVolume) }
    }

    /// Chimes the user brought in from Files, Voice Memos or the Music app.
    static var importedSounds: [StartupSound] {
        get { decode([StartupSound].self, Key.importedSounds) ?? [] }
        set { encode(newValue, Key.importedSounds) }
    }

    // MARK: - Widgets

    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Coding

    private static func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults?.set(data, forKey: key)
        reloadWidgets()
    }
}
