import SwiftUI

/// Walkthrough for the Shortcuts automation — the half of the hybrid setup that
/// works with the app fully closed.
struct ShortcutsGuideView: View {
    private let steps: [(String, String, String)] = [
        ("1", "Abre Atajos", "Ve a la pestaña Automatización y toca el + arriba a la derecha."),
        ("2", "Elige «CarPlay»", "Marca «Se conecta» y desactiva «Preguntar antes de ejecutar»."),
        ("3", "Añade la acción", "Busca «Reproducir sonido de arranque» — es la acción de esta app."),
        ("4", "Listo", "Se dispara al conectar, aunque la app esté cerrada. El sonido es el que tengas elegido aquí.")
    ]

    var body: some View {
        List {
            Section {
                ForEach(steps, id: \.0) { step in
                    HStack(alignment: .top, spacing: 14) {
                        Text(step.0)
                            .font(.headline)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.accentColor.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.1).font(.body.weight(.semibold))
                            Text(step.2).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Apple reproduce siempre su aviso de conexión antes: no hay forma de silenciarlo desde una app.")
            }

            Section {
                Button("Abrir Atajos", systemImage: "arrow.up.forward.app") {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("Atajos")
        .navigationBarTitleDisplayMode(.inline)
    }
}
