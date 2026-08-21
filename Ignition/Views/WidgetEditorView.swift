import SwiftUI

/// Live editor for a widget design. The preview above is the very same view the
/// widget extension renders, so there is no gap between editing and the dashboard.
struct WidgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var garage = Garage.shared
    @State private var draft: WidgetDesign

    init(design: WidgetDesign) {
        _draft = State(initialValue: design)
    }

    private var vehicle: VehicleProfile? { garage.vehicle(for: draft) }
    private var photo: UIImage? { garage.photo(for: draft) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview
                    controls
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Diseño")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") {
                        garage.update(draft)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 10) {
            // A dark stage stands in for the car screen, which is where this widget
            // spends its life.
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(0.9))
                WidgetPreview(design: draft, vehicle: vehicle, photo: photo, size: 170)
            }
            .frame(height: 230)
            Text("Vista previa a tamaño real")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 18) {
            group("Nombre") {
                TextField("Nombre del diseño", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
            }

            group("Coche") {
                Picker("Coche", selection: Binding(
                    get: { draft.vehicleID ?? garage.vehicles.first?.id },
                    set: { draft.vehicleID = $0 }
                )) {
                    ForEach(garage.vehicles) { vehicle in
                        Text(vehicle.displayName).tag(Optional(vehicle.id))
                    }
                }
                .pickerStyle(.segmented)
            }

            group("Composición") {
                Picker("Composición", selection: $draft.layout) {
                    ForEach(WidgetLayout.allCases) { layout in
                        Text(layout.localizedName).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
            }

            group("Fondo") {
                Picker("Fondo", selection: $draft.background) {
                    ForEach(BackgroundKind.allCases) { kind in
                        Text(kind.localizedName).tag(kind)
                    }
                }
                .pickerStyle(.menu)

                if draft.background == .solid {
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: draft.backgroundHex) },
                        set: { draft.backgroundHex = $0.hexString }
                    ), supportsOpacity: false)
                }

                if draft.background == .photo {
                    if vehicle?.photoFileName == nil {
                        Label("Este coche no tiene foto todavía", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    LabeledContent("Oscurecer") {
                        Slider(value: $draft.photoDim, in: 0...0.85)
                    }
                }
            }

            group("Elementos") {
                Toggle("Emblema", isOn: $draft.showsLogo)
                Toggle("Marca y modelo", isOn: $draft.showsModel)
                Toggle("Matrícula", isOn: $draft.showsPlate)
                Toggle("Hora", isOn: $draft.showsClock)
            }

            group("Esquinas") {
                LabeledContent("Redondeo") {
                    Slider(value: $draft.cornerRadius, in: 0...40)
                }
                Text("En el coche el widget no lleva fondo del sistema, así que este redondeo es el que se ve.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .kerning(0.8)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
