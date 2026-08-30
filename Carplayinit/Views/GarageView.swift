import SwiftUI
import WidgetKit

/// Home: your cars, the widget designs made from them, and the shortcut to add more.
struct GarageView: View {
    @State private var garage = Garage.shared
    @State private var watcher = CarConnectionWatcher.shared
    @State private var showingNewVehicle = false
    @State private var showingGuide = false
    @State private var editingDesign: WidgetDesign?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    connectionBanner

                    if garage.vehicles.isEmpty {
                        emptyState
                    } else {
                        designsSection
                        vehiclesSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Garaje")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cómo se usa", systemImage: "questionmark.circle") { showingGuide = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Añadir coche", systemImage: "plus") { showingNewVehicle = true }
                }
            }
            .sheet(isPresented: $showingGuide) {
                NavigationStack {
                    GuideView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Hecho") { showingGuide = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingNewVehicle) {
                VehicleEditorView(vehicle: nil)
            }
            .sheet(item: $editingDesign) { design in
                WidgetEditorView(design: design)
            }
            .onAppear { garage.reload() }
        }
    }

    // MARK: - Sections

    private var connectionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: watcher.isConnectedToCar ? "car.fill" : "car")
                .font(.title2)
                .foregroundStyle(watcher.isConnectedToCar ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(watcher.isConnectedToCar ? "Conectado al coche" : "Sin conexión al coche")
                    .font(.subheadline.weight(.semibold))
                Text(watcher.isConnectedToCar
                     ? watcher.currentRouteName
                     : "Se detecta al conectar CarPlay o el Bluetooth del coche.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.top, 4)
    }

    private var designsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Widgets", subtitle: "Así se verán en el salpicadero")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(garage.designs) { design in
                        Button {
                            editingDesign = design
                        } label: {
                            WidgetPreview(design: design,
                                          vehicle: garage.vehicle(for: design),
                                          photo: garage.photo(for: design))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Duplicar", systemImage: "plus.square.on.square") {
                                var copy = design
                                copy.id = UUID()
                                copy.name = design.name + " 2"
                                garage.add(copy)
                            }
                            Button("Eliminar", systemImage: "trash", role: .destructive) {
                                garage.delete(design)
                            }
                        }
                    }
                    newDesignButton
                }
                .padding(.vertical, 4)
            }
            Text("Mantén pulsado el widget en el iPhone o en el coche → Editar widget → elige el diseño.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var newDesignButton: some View {
        Button {
            guard let vehicle = garage.vehicles.first else { return }
            let design = WidgetDesign.makeDefault(for: vehicle)
            garage.add(design)
            editingDesign = design
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2)
                Text("Nuevo diseño")
                    .font(.caption.weight(.medium))
            }
            .frame(width: 158, height: 158)
            .foregroundStyle(.secondary)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var vehiclesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Mis coches", subtitle: nil)
            ForEach(garage.vehicles) { vehicle in
                NavigationLink {
                    VehicleEditorView(vehicle: vehicle)
                } label: {
                    VehicleRow(vehicle: vehicle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Aún no hay coches", systemImage: "car.2.fill")
        } description: {
            Text("Añade tu coche para crear widgets con su emblema, su foto y su matrícula.")
        } actions: {
            Button("Añadir coche") { showingNewVehicle = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }
}

// MARK: - Pieces

struct SectionHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// The widget artwork at its real size, so the editor is honest about the result.
struct WidgetPreview: View {
    let design: WidgetDesign
    let vehicle: VehicleProfile?
    let photo: UIImage?
    var size: CGFloat = 158

    var body: some View {
        CarWidgetCard(design: design, vehicle: vehicle, photo: photo)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: design.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

struct VehicleRow: View {
    let vehicle: VehicleProfile

    var body: some View {
        HStack(spacing: 14) {
            BrandMark(brand: vehicle.brand, size: 34,
                      tint: Color(hex: vehicle.brand?.primaryHex ?? "#888888"))
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.displayName).font(.body.weight(.semibold))
                Text(vehicle.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
