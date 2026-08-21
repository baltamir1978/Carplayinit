import Foundation

/// A car marque: identity, palette and the models we offer in the picker.
///
/// Logo artwork is *not* bundled with the catalog. `logoAssetName` points at an
/// image the app looks up at runtime (see `Brands/README.md`); when it is missing
/// the UI falls back to a monogram built from `name`, so the app works — and ships —
/// with or without trademarked artwork.
struct Brand: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    /// ISO 3166-1 alpha-2 of the marque's origin, used for the flag chip.
    let country: String
    let primaryHex: String
    let secondaryHex: String
    let accentHex: String
    let models: [String]

    /// Asset name looked up in the main bundle and in the widget bundle.
    var logoAssetName: String { "logo-\(id)" }

    /// Two-letter monogram used when no logo artwork is installed.
    var monogram: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return words.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

/// The bundled marque catalog, loaded once from `brands.json`.
enum BrandCatalog {
    static let all: [Brand] = load()

    static func brand(id: String?) -> Brand? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func search(_ query: String) -> [Brand] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { brand in
            brand.name.localizedCaseInsensitiveContains(q)
                || brand.models.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    private static func load() -> [Brand] {
        // The JSON is a resource of both the app and the widget extension.
        guard let url = Bundle.main.url(forResource: "brands", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let brands = try? JSONDecoder().decode([Brand].self, from: data) else {
            assertionFailure("brands.json missing from bundle")
            return []
        }
        return brands.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
