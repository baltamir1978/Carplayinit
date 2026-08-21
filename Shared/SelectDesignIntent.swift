import AppIntents
import WidgetKit

/// One saved design, exposed to the widget configuration sheet and to Shortcuts.
struct DesignEntity: AppEntity, Identifiable {
    var id: UUID
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Diseño")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static let defaultQuery = DesignQuery()

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(_ design: WidgetDesign) {
        self.id = design.id
        self.name = design.name.isEmpty ? design.layout.localizedName : design.name
    }
}

struct DesignQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [DesignEntity] {
        SharedStore.designs.filter { identifiers.contains($0.id) }.map(DesignEntity.init)
    }

    func suggestedEntities() async throws -> [DesignEntity] {
        SharedStore.designs.map(DesignEntity.init)
    }

    func defaultResult() async -> DesignEntity? {
        SharedStore.designs.first.map(DesignEntity.init)
    }
}

/// Configuration for the car widget: long-press → Edit → pick one of your designs.
struct SelectDesignIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Elegir diseño"
    static let description = IntentDescription("Elige qué diseño de coche muestra este widget.")

    @Parameter(title: "Diseño")
    var design: DesignEntity?

    init() {}

    init(design: DesignEntity?) {
        self.design = design
    }
}
