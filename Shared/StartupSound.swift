import Foundation

/// Where a chime's audio file lives.
enum SoundStorage: String, Codable {
    /// Shipped inside the app bundle.
    case bundle
    /// Written into the App Group container — synthesised chimes and user imports.
    case container
}

/// A startup chime.
struct StartupSound: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var packID: String
    var storage: SoundStorage = .container
    var fileName: String
    var duration: Double = 0

    var url: URL? {
        switch storage {
        case .container:
            return SharedStore.soundsDirectory.appendingPathComponent(fileName)
        case .bundle:
            let name = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            return Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "m4a" : ext)
        }
    }
}

/// A themed group of chimes.
struct SoundPack: Identifiable, Hashable {
    var id: String
    var name: String
    var subtitle: String
    var symbol: String
    var sounds: [StartupSound]
}


/// Lets a picked file drive `.sheet(item:)` without a wrapper type.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
