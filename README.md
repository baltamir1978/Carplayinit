# Ignition

App de iOS para personalizar el coche desde el iPhone: **widgets de coche** que iOS 26
lleva al salpicadero de CarPlay y un **sonido de arranque** propio al conectarse.

**Versión actual: 1.0** · iOS 26.5 · Xcode 26

Build privado para tres coches concretos:

| Coche | Pintura |
|---|---|
| Land Rover Defender 110 | verde mate (`#3E4A3B`, acabado mate) |
| BYD Dolphin | gris (`#8C9195`, brillo) |
| Leapmotor T03 | azul claro (`#A9CDE6`, brillo) |

## Qué hace

- 🚗 **Garaje**: marca, modelo, matrícula, foto y **color de carrocería con acabado**
  (brillo / satinado / mate). El mate no es sólo un color plano: se dibuja sin reflejo
  especular y con grano, que es lo que lo hace leer como mate en pantalla.
- 🧩 **Widgets** (WidgetKit, `systemSmall` y `systemMedium`) con cuatro composiciones —
  emblema, foto, matrícula y mínimo — y cinco fondos: degradado de marca, color sólido,
  foto del coche, fibra de carbono y color real de la carrocería.
  Configurables desde el propio widget (`AppIntentConfiguration`): mantén pulsado →
  *Editar widget* → elige diseño.
- 🔊 **Sonido de arranque** al conectar (y opcionalmente al desconectar), con
  **20 chimes sintetizados** en cinco packs e importación de audio propio.
- 🎚️ **Nivelado a −12 dBFS**: todo lo que suena, generado o importado, sale al mismo
  nivel. Las unidades de a bordo reproducen los avisos bastante más alto que la música;
  un clip masterizado a 0 dBFS es un susto a las siete de la mañana.
- 🎛️ **Mezclador de dos pistas**: una principal sobre una base de música con *ducking*
  y fundidos, por si el clip hay que montarlo.
- 🗣️ **Atajo de Siri / Automatización** (`PlayStartupSoundIntent`) para dispararlo con
  la app cerrada.

## Cómo se usa

La app lleva estas mismas instrucciones dentro: **Garaje → ? (arriba a la izquierda)** o
**Ajustes → Cómo se usa**.

### Widgets

1. **Garaje** → toca un widget para abrir el editor: composición, fondo y qué datos se ven.
   La vista previa es exactamente lo que se verá en el coche.
2. En la pantalla de inicio del iPhone, mantén pulsado → **+** → busca *Ignition* → añade el
   widget pequeño.
3. Mantén pulsado el widget ya colocado → **Editar widget → Diseño**. Cada widget puede
   llevar un coche distinto.

### En el coche

1. **Ajustes → General → CarPlay → tu coche → Personalizar** para elegir qué widgets salen
   en el salpicadero.
2. Con el coche conectado, mantén pulsado el widget del panel de CarPlay y elige *Ignition*.

Requiere **iOS 26 o posterior**: es la versión que lleva los widgets del iPhone al
salpicadero de cualquier coche compatible.

### Sonido de arranque

1. Pestaña **Sonidos** → ▶︎ para escuchar, el círculo de la derecha para dejarlo elegido.
2. **Importar un audio** para traer el tuyo: cualquier `.m4a` o `.mp3` de la app Archivos.
   Se recorta a 10 s y se nivela a −12 dBFS solo. Los temas de Apple Music llevan DRM y no
   se pueden importar.
3. **Ajustes → Volumen**, y *Probar ahora* para oírlo sin salir de casa.

### Para que suene con la app cerrada

- **Ajustes → Mantener a la escucha**: la app sigue atenta en segundo plano. Gasta batería.
- **Ajustes → Automatización con Atajos**: automatización *Al conectar CarPlay → Reproducir
  sonido de arranque*. Se dispara aunque Ignition lleve días sin abrirse. Es la opción a
  prueba de balas y conviene tener las dos.

## Los widgets en el coche

Desde **iOS 26** CarPlay muestra en el salpicadero los widgets del iPhone: no hace falta
el *entitlement* de CarPlay ni ser una "app de CarPlay". El sistema los renderiza en
estilo StandBy — `systemSmall`, a todo color y **sin fondo de contenedor**, por eso
`CarWidgetCard` pinta su propio fondo y redondea sus propias esquinas.

Para activarlos: **Ajustes → General → CarPlay → tu coche → Personalizar**.

Se prueban sin coche con el **CarPlay Simulator** de Xcode (*Xcode → Open Developer
Tool → Simulator*, y en el simulador *I/O → External Displays → CarPlay*).

## El sonido de arranque, sin humo

No existe API pública para sustituir el aviso de conexión de CarPlay: **el de Apple suena
siempre primero**. Lo que hace Ignition es reconocer el momento en que el móvil entra en
el coche y colocar el clip justo detrás. Dos caminos, y conviene tener los dos:

1. **Dentro de la app** (`CarConnectionWatcher`): escucha
   `AVAudioSession.routeChangeNotification` y comprueba si la salida pasa a ser
   `.carAudio` (CarPlay) o Bluetooth A2DP/HFP. Con *Mantener a la escucha* activado, un
   bucle de silencio mantiene viva la sesión de audio en segundo plano para poder oír ese
   cambio horas después. Gasta batería: es un ajuste, no un comportamiento impuesto.
2. **Atajos** (`PlayStartupSoundIntent`): automatización *Al conectar CarPlay → Reproducir
   sonido de arranque*. Funciona con la app cerrada. Guía paso a paso en Ajustes → Atajos.

## Los emblemas

El proyecto **no incluye los logos de las marcas**: son marcas registradas. Cuando falta
el asset, `BrandMark` dibuja un monograma con las iniciales en el color corporativo — que
es lo que se ve ahora mismo. Para ponerlos, mira `Brands/README.md`: es arrastrar un PNG,
sin tocar código.

## Estructura

```
Carplay/
├── Ignition.xcodeproj          # generado por Tools/generate_project.rb
├── Ignition/                   # target principal
│   ├── IgnitionApp.swift
│   ├── Model/
│   │   ├── Garage.swift        # coches y diseños, sobre el App Group
│   │   └── GarageSeed.swift    # los tres coches precargados
│   ├── Audio/
│   │   ├── CarConnectionWatcher.swift   # detección de coche + keep-alive
│   │   ├── StartupSoundPlayer.swift
│   │   ├── ChimeSynth.swift             # síntesis y escritura WAV
│   │   ├── ChimeRecipes.swift           # los 20 chimes, como datos
│   │   ├── AudioNormalizer.swift        # import, recorte, −12 dBFS, mezcla
│   │   └── SoundLibrary.swift
│   ├── Intents/StartupSoundIntents.swift
│   └── Views/                  # Garaje, editor de coche, editor de widget, sonidos, ajustes
├── IgnitionWidget/             # extensión WidgetKit
├── Shared/                     # compilado en AMBOS targets
│   ├── brands.json             # catálogo de marcas (recurso de los dos bundles)
│   ├── Brand.swift  VehicleProfile.swift  WidgetDesign.swift  StartupSound.swift
│   ├── SharedStore.swift       # App Group: group.Altamirano.Ignition
│   ├── CarWidgetCard.swift     # la vista del widget, compartida con la vista previa
│   └── SelectDesignIntent.swift
├── Brands/Brands.xcassets      # huecos para los emblemas
└── Tools/generate_project.rb
```

`Shared/` se compila en el target de la app **y** en el de la extensión: una extensión no
puede leer los recursos de la app que la contiene, así que `brands.json` y el catálogo de
emblemas se copian a los dos *bundles*.

## Compilar

```bash
ruby Tools/generate_project.rb     # regenera Ignition.xcodeproj desde el árbol
open Ignition.xcodeproj
```

El `.xcodeproj` está generado, no editado a mano: añadir un archivo Swift es añadirlo a su
carpeta y volver a ejecutar el script.

Capabilities ya configuradas en los entitlements: **App Groups**
(`group.Altamirano.Ignition`) en los dos targets y **Background Modes → Audio** en la app.
