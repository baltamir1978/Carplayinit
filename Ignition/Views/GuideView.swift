import SwiftUI

/// In-app instructions. Everything here is something the user has to do *outside*
/// the app — in Ajustes, in the widget gallery, in Atajos — so it cannot be solved
/// with better UI; it has to be written down where they will look for it.
struct GuideView: View {
    var body: some View {
        List {
            Section {
                Step(number: "1", title: "Crea tu diseño",
                     detail: "Garaje → toca un widget para abrir el editor. Elige composición, fondo y qué datos se ven. La vista previa es exactamente lo que verás en el coche.")
                Step(number: "2", title: "Pon el widget en el iPhone",
                     detail: "Mantén pulsada la pantalla de inicio → + arriba a la izquierda → busca «Ignition» → añade el widget pequeño.")
                Step(number: "3", title: "Elige el diseño en el widget",
                     detail: "Mantén pulsado el widget ya colocado → Editar widget → Diseño. Cada widget puede llevar un coche distinto.")
            } header: {
                Label("Widgets", systemImage: "square.grid.2x2.fill")
            }

            Section {
                Step(number: "1", title: "Activa los widgets del coche",
                     detail: "En el iPhone: Ajustes → General → CarPlay → tu coche → Personalizar. Ahí decides qué widgets salen en el salpicadero.")
                Step(number: "2", title: "Colócalo en el salpicadero",
                     detail: "Con el coche conectado, en la pantalla de CarPlay mantén pulsado el widget del panel y elige Ignition.")
                InfoNote("Necesitas iOS 26 o posterior. Desde esa versión CarPlay muestra los widgets del iPhone en cualquier coche compatible, sin apps especiales.")
            } header: {
                Label("En el coche", systemImage: "car.fill")
            }

            Section {
                Step(number: "1", title: "Elige un sonido",
                     detail: "Pestaña Sonidos → toca ▶︎ para escucharlo y el círculo de la derecha para dejarlo elegido. El pack Destacado es el clip que viene preparado de casa.")
                Step(number: "2", title: "O trae el tuyo",
                     detail: "Sonidos → Importar un audio. Vale cualquier .m4a o .mp3 de Archivos. Se abre el recortador: arrastra sobre la onda para elegir el trozo (máx. 10 s), escúchalo y guárdalo.")
                Step(number: "3", title: "¿Está dentro de un vídeo?",
                     detail: "Guarda el vídeo en Fotos y monta un atajo con «Codificar contenido multimedia» y «Sólo audio» activado: deja un .m4a en Archivos listo para importar.")
                Step(number: "4", title: "Ajusta el volumen",
                     detail: "Ajustes → Volumen, y «Probar ahora» para oírlo sin salir de casa.")
                InfoNote("Los temas comprados o descargados de Apple Music llevan DRM y no se pueden importar: tiene que ser un archivo suelto en la app Archivos.")
            } header: {
                Label("Sonido de arranque", systemImage: "speaker.wave.2.fill")
            }

            Section {
                Step(number: "1", title: "Con la app en marcha",
                     detail: "Ignition reconoce el momento en que el móvil entra en el coche y suelta el clip. Para que funcione con la app en segundo plano, activa Ajustes → Mantener a la escucha (gasta algo de batería).")
                Step(number: "2", title: "Con la app cerrada",
                     detail: "Monta la automatización de Atajos: Ajustes → Automatización con Atajos. Se dispara siempre, aunque Ignition lleve días sin abrirse.")
                InfoNote("CarPlay hace sonar su propio aviso de conexión antes que el tuyo. No hay forma de silenciarlo desde una app: el clip entra justo detrás.")
            } header: {
                Label("Cuándo suena", systemImage: "bolt.horizontal.fill")
            }

            Section {
                Step(number: "1", title: "Los emblemas",
                     detail: "Mientras no haya logo instalado para una marca, se dibuja un monograma con sus iniciales. Los logos se añaden en el proyecto, en Brands/Brands.xcassets.")
                Step(number: "2", title: "Tu coche, tu color",
                     detail: "Garaje → toca el coche → Pintura. El acabado mate quita el reflejo y añade grano; el brillo pone el punto de luz.")
            } header: {
                Label("Detalles", systemImage: "paintbrush.fill")
            }
        }
        .navigationTitle("Cómo se usa")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Pieces

private struct Step: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.subheadline.weight(.bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct InfoNote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.tint)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
