# Carplayinit

App de iOS para personalizar el coche desde el iPhone: **widgets de coche** que iOS 26
lleva al salpicadero de CarPlay y un **sonido de arranque** propio al conectarse.

**Versión actual: 1.0** · iOS 26.5 · Xcode 26

El garaje viene precargado con tres coches concretos, pero la marca sale de un
catálogo de 24 y el modelo se escribe libre: cualquier coche cabe.

| Coche | Pintura |
|---|---|
| Land Rover Defender 110 | verde mate (`#3E4A3B`, acabado mate) |
| BYD Dolphin G DM-i | gris (`#8C9195`, brillo) |
| Leapmotor T03 | azul claro (`#A9CDE6`, brillo) |

## Qué hace

- 🚗 **Garaje**: marca (24 en el catálogo), modelo en texto libre, matrícula con su
  país, foto y **color de carrocería con acabado**
  (brillo / satinado / mate). El mate no es sólo un color plano: se dibuja sin reflejo
  especular y con grano, que es lo que lo hace leer como mate en pantalla.
- 🧩 **Widgets** (WidgetKit, `systemSmall` y `systemMedium`) con cuatro composiciones —
  emblema, foto, matrícula y mínimo — y cinco fondos: degradado de marca, color sólido,
  foto del coche, fibra de carbono y color real de la carrocería.
  Configurables desde el propio widget (`AppIntentConfiguration`): mantén pulsado →
  *Editar widget* → elige diseño.
- 🔊 **Sonido de arranque** al conectar (y opcionalmente al desconectar), con
  **24 chimes sintetizados** en seis packs e importación de audio propio.
- ⭐️ **Clip propio de fábrica**: el audio que dejes preparado con
  `Tools/prepare_clip.sh` aparece como pack *Destacado* y queda elegido de salida. El
  archivo **no viaja en el repo** — es una grabación ajena —, así que sin él la app cae
  sola en los chimes sintetizados.
- ✂️ **Recorte con forma de onda**: al importar, eliges el fragmento arrastrando sobre la
  onda (hasta 10 s) en vez de quedarte con el principio del archivo. Los bordes llevan
  fundido, que es lo que evita el chasquido al cortar por el medio.
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
2. En la pantalla de inicio del iPhone, mantén pulsado → **+** → busca *Carplayinit* → añade el
   widget pequeño.
3. Mantén pulsado el widget ya colocado → **Editar widget → Diseño**. Cada widget puede
   llevar un coche distinto.

### En el coche

1. **Ajustes → General → CarPlay → tu coche → Personalizar** para elegir qué widgets salen
   en el salpicadero.
2. Con el coche conectado, mantén pulsado el widget del panel de CarPlay y elige *Carplayinit*.

Requiere **iOS 26 o posterior**: es la versión que lleva los widgets del iPhone al
salpicadero de cualquier coche compatible.

### Sonido de arranque

1. Pestaña **Sonidos** → ▶︎ para escuchar, el círculo de la derecha para dejarlo elegido.
2. **Importar un audio** para traer el tuyo: cualquier `.m4a` o `.mp3` de la app Archivos.
   Se abre el recortador: arrastra sobre la onda para elegir el trozo (máx. 10 s), escúchalo
   y guárdalo. Se nivela a −12 dBFS solo. Los temas de Apple Music llevan DRM y no se pueden
   importar.

   ¿Sacar el audio de un vídeo? En el iPhone, sin apps de terceros: guarda el vídeo en
   Fotos y crea un atajo con **Codificar contenido multimedia → Sólo audio: sí**, que deja
   un `.m4a` en Archivos listo para importar.
3. **Ajustes → Volumen**, y *Probar ahora* para oírlo sin salir de casa.

### Para que suene con la app cerrada

- **Ajustes → Mantener a la escucha**: la app sigue atenta en segundo plano. Gasta batería.
- **Ajustes → Automatización con Atajos**: automatización *Al conectar CarPlay → Reproducir
  sonido de arranque*. Se dispara aunque Carplayinit lleve días sin abrirse. Es la opción a
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
siempre primero**. Lo que hace Carplayinit es reconocer el momento en que el móvil entra en
el coche y colocar el clip justo detrás. Dos caminos, y conviene tener los dos:

1. **Dentro de la app** (`CarConnectionWatcher`): escucha
   `AVAudioSession.routeChangeNotification` y comprueba si la salida pasa a ser
   `.carAudio` (CarPlay) o Bluetooth A2DP/HFP. Con *Mantener a la escucha* activado, un
   bucle de silencio mantiene viva la sesión de audio en segundo plano para poder oír ese
   cambio horas después. Gasta batería: es un ajuste, no un comportamiento impuesto.
2. **Atajos** (`PlayStartupSoundIntent`): automatización *Al conectar CarPlay → Reproducir
   sonido de arranque*. Funciona con la app cerrada. Guía paso a paso en Ajustes → Atajos.

## El clip de arranque propio

```bash
Tools/prepare_clip.sh ~/Downloads/mi-audio.mp3 [inicio] [duración]
```

Lo pasa a mono, recorta el fragmento (por defecto los primeros 8 s), le pone fundidos,
lo nivela a −12 dBFS y lo deja en `Carplayinit/Resources/startup-clip.m4a`. Sin inicio ni
duración coge el archivo **entero**: el límite de 10 s del importador de la app no aplica
a un clip que viaja dentro del bundle. No hace falta
tocar el proyecto: una fase de build lo copia al bundle si está, y si no está avisa por
consola y la app tira de los chimes sintetizados.

Para quedarte sólo con un trozo, pásale los segundos — por ejemplo
`Tools/prepare_clip.sh mi-audio.mp3 3 4` coge cuatro segundos a partir del tercero.

`Carplayinit/Resources/` está en el `.gitignore`: el repo es público y ese audio no es
nuestro para redistribuirlo.

## Los emblemas

El proyecto **no incluye los logos de las marcas**: son marcas registradas. Cuando falta
el asset, `BrandMark` dibuja un monograma con las iniciales en el color corporativo — que
es lo que se ve ahora mismo. Para ponerlos, mira `Brands/README.md`: es arrastrar un PNG,
sin tocar código.

## Estructura

```
Carplayinit/
├── Carplayinit.xcodeproj          # generado por Tools/generate_project.rb
├── Carplayinit/                   # target principal
│   ├── CarplayinitApp.swift
│   ├── Model/
│   │   ├── Garage.swift        # coches y diseños, sobre el App Group
│   │   ├── GarageSeed.swift    # los tres coches precargados
│   │   └── LegacyMigration.swift  # rescate de los datos de la versión «Ignition»
│   ├── Audio/
│   │   ├── CarConnectionWatcher.swift   # detección de coche + keep-alive
│   │   ├── StartupSoundPlayer.swift
│   │   ├── ChimeSynth.swift             # síntesis y escritura WAV
│   │   ├── ChimeRecipes.swift           # los 24 chimes, como datos
│   │   ├── AudioNormalizer.swift        # import, recorte, −12 dBFS, mezcla
│   │   └── SoundLibrary.swift
│   ├── Intents/StartupSoundIntents.swift
│   └── Views/                  # Garaje, editor de coche, editor de widget, sonidos, ajustes
├── CarplayinitWidget/             # extensión WidgetKit
├── Shared/                     # compilado en AMBOS targets
│   ├── brands.json             # catálogo de marcas (recurso de los dos bundles)
│   ├── Brand.swift  VehicleProfile.swift  WidgetDesign.swift  StartupSound.swift
│   ├── SharedStore.swift       # App Group: group.Altamirano.Carplayinit
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
ruby Tools/generate_project.rb     # regenera Carplayinit.xcodeproj desde el árbol
open Carplayinit.xcodeproj
```

El `.xcodeproj` está generado, no editado a mano: añadir un archivo Swift es añadirlo a su
carpeta y volver a ejecutar el script.

Capabilities ya configuradas en los entitlements: **App Groups**
(`group.Altamirano.Carplayinit`) en los dos targets y **Background Modes → Audio** en la app.

La app declara además el App Group antiguo `group.Altamirano.Ignition`, y sólo por eso:
esta app se llamó Ignition, y renombrarla cambió el grupo — que para iOS es otro
contenedor, con el garaje y los sonidos importados dentro. `LegacyMigration` los copia
la primera vez que arranca y no vuelve a tocarlo. Si nunca tuviste Ignition instalada,
no hay nada que copiar y puedes quitar esa línea de
`Carplayinit/Carplayinit.entitlements`.
