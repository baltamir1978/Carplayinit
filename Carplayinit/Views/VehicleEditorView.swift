import SwiftUI
import PhotosUI

/// Add or edit a car. Doubles as the sheet for "Añadir coche".
struct VehicleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var garage = Garage.shared
    @State private var draft: VehicleProfile
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var showingDeleteConfirmation = false

    private let isNew: Bool

    init(vehicle: VehicleProfile?) {
        let initial = vehicle ?? VehicleProfile(brandID: BrandCatalog.all.first?.id ?? "byd",
                                                model: BrandCatalog.all.first?.models.first ?? "")
        _draft = State(initialValue: initial)
        _photo = State(initialValue: initial.photoURL.flatMap { UIImage(contentsOfFile: $0.path) })
        isNew = vehicle == nil
    }

    private var brand: Brand? { BrandCatalog.brand(id: draft.brandID) }

    var body: some View {
        Form {
            Section {
                Picker("Marca", selection: $draft.brandID) {
                    ForEach(BrandCatalog.all) { brand in
                        Text(brand.name).tag(brand.id)
                    }
                }
                .onChange(of: draft.brandID) { oldValue, newValue in
                    // Only follow the marque while the model came from its own
                    // list: a model typed by hand is the user's, not a leftover.
                    let previous = BrandCatalog.brand(id: oldValue)?.models ?? []
                    guard draft.model.isEmpty || previous.contains(draft.model) else { return }
                    draft.model = BrandCatalog.brand(id: newValue)?.models.first ?? ""
                }

                modelField

                TextField("Nombre (opcional)", text: $draft.nickname)
                    .textInputAutocapitalization(.words)

                TextField("Matrícula", text: $draft.plate)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                TextField("País de la matrícula", text: Binding(
                    get: { draft.plateCountry ?? VehicleProfile.defaultPlateCountry },
                    set: { draft.plateCountry = $0.uppercased() }
                ))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            } header: {
                Text("Coche")
            } footer: {
                Text("El modelo se escribe libre: la lista es sólo un atajo. El país es el de la banda azul de la matrícula (E, F, P, D…).")
            }

            Section("Pintura") {
                ColorPicker("Color de carrocería",
                            selection: Binding(
                                get: { Color(hex: draft.paintHex) },
                                set: { draft.bodyColorHex = $0.hexString }
                            ),
                            supportsOpacity: false)

                Picker("Acabado", selection: $draft.finish) {
                    ForEach(PaintFinish.allCases) { finish in
                        Text(finish.localizedName).tag(finish)
                    }
                }
                .pickerStyle(.segmented)

                PaintFinishBackground(hex: draft.paintHex, finish: draft.finish)
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Foto") {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                photoPicker
                if photo != nil {
                    Button("Quitar foto", systemImage: "trash", role: .destructive) {
                        draft = garage.removePhoto(from: draft)
                        photo = nil
                    }
                }
            }

            if !isNew {
                Section {
                    Button("Eliminar coche", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(isNew ? "Nuevo coche" : draft.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { save() }
            }
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                photo = image
                // Saving needs the vehicle to exist first; for a new car we defer
                // to `save()`.
                if !isNew { draft = garage.savePhoto(image, for: draft) }
            }
        }
        .confirmationDialog("¿Eliminar este coche?", isPresented: $showingDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                garage.delete(draft)
                dismiss()
            }
        } message: {
            Text("Se borrarán también sus diseños de widget.")
        }
        .wrappedInNavigationStack(isNew)
    }

    /// Free text, with the marque's catalog hanging off a menu. A picker alone
    /// meant a car outside the catalog simply could not be added.
    private var modelField: some View {
        HStack {
            TextField("Modelo", text: $draft.model)
                .textInputAutocapitalization(.words)
            if let models = brand?.models, !models.isEmpty {
                Menu {
                    ForEach(models, id: \.self) { model in
                        Button(model) { draft.model = model }
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    /// The title is resolved before the picker's closure so nothing main-actor
    /// isolated gets captured by it.
    private var photoPicker: some View {
        let title = photo == nil ? "Elegir foto" : "Cambiar foto"
        return PhotosPicker(selection: $photoItem, matching: .images) {
            Label(title, systemImage: "photo")
        }
    }

    private func save() {
        if isNew {
            garage.add(draft)
            if let photo { _ = garage.savePhoto(photo, for: draft) }
        } else {
            garage.update(draft)
        }
        dismiss()
    }
}

private extension View {
    /// Sheets need their own stack; pushed screens already have one.
    @ViewBuilder
    func wrappedInNavigationStack(_ wrap: Bool) -> some View {
        if wrap {
            NavigationStack { self }
        } else {
            self
        }
    }
}
