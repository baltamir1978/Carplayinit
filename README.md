# Carplayinit

Widgets de coche para el salpicadero de CarPlay y un sonido de arranque propio al
conectar el iPhone. App de iOS en SwiftUI, sin dependencias.

**1.0** · requiere **iOS 26** · se compila con Xcode 26

Desde iOS 26 CarPlay muestra en el salpicadero los widgets del iPhone, sin que la app
tenga que ser una «app de CarPlay» ni pedir el *entitlement*. Carplayinit aprovecha eso
para poner ahí el emblema, la foto o la matrícula de tu coche, y de paso se ocupa de lo
otro que iOS no deja personalizar: el sonido de al entrar en el coche.

---

## Qué hace

**Un garaje con tus coches.** Marca de un catálogo de 24, modelo escrito libre, matrícula
con su país, foto y color de carrocería **con acabado**: brillo, satinado o mate. El mate
no es un color plano — se dibuja sin reflejo especular y con grano, que es justo lo que
lo hace leer como mate en una pantalla.

El garaje arranca con tres coches ya puestos —los que motivaron la app—, y son editables
o borrables como cualquier otro:

| Coche | Pintura |
|---|---|
| Land Rover Defender 110 | verde `#3E4A3B`, mate |
| BYD Dolphin G DM-i | gris `#8C9195`, brillo |
| Leapmotor T03 | azul claro `#A9CDE6`, brillo |

**Widgets configurables.** Cuatro composiciones (emblema, foto, matrícula y mínimo) sobre
cinco fondos (degradado de marca, color sólido, foto, fibra de carbono y el color real de
la carrocería). Se editan dentro de la app con vista previa a tamaño real, y se eligen
desde el propio widget: mantén pulsado → *Editar widget*. Cada widget puede llevar un
coche distinto.

**Sonido de arranque al conectar**, y opcionalmente al desconectar. Vienen 24 chimes
repartidos en seis packs, y puedes traer el tuyo desde la app Archivos.

**Recorte sobre la forma de onda.** Al importar eliges el fragmento arrastrando sobre la
onda, hasta 60 s, en vez de quedarte con el principio del archivo — el segundo bueno de
un clip sacado de un vídeo casi nunca es el primero. Los bordes llevan fundido, que es lo
que evita el chasquido de cortar por el medio.

**Todo nivelado a −12 dBFS.** Generado o importado, sale al mismo volumen. No es un número
caprichoso: las unidades de a bordo reproducen los avisos bastante más alto que la música,
y un clip masterizado a 0 dBFS es un susto a las siete de la mañana.

**Texto a voz.** Escribes lo que quieres oír y el iPhone lo dice, con dos caracteres:
una **grave y pausada** y otra **aguda y despierta**. El resultado se nivela y se
guarda como un sonido más. Conviene instalar voces buenas (*Ajustes → Accesibilidad →
Contenido hablado → Voces → Español*); la app lo recuerda y avisa cuando le falta la
voz del género que le pides.

**Mezclador de dos pistas**, por si el clip hay que montarlo: una principal sobre una base
de música, con *ducking* y fundidos.

**Atajo de Siri y automatización** (`PlayStartupSoundIntent`), para que suene con la app
cerrada.

---

## Cómo se usa

La app lleva estas mismas instrucciones dentro: **Garaje → ?** (arriba a la izquierda) o
**Ajustes → Cómo se usa**.

### Los widgets

1. **Garaje** → toca un widget para abrir el editor. La vista previa es exactamente lo que
   se verá en el coche.
2. En la pantalla de inicio del iPhone: mantén pulsado → **+** → busca *Carplayinit* →
   añade el widget pequeño.
3. Mantén pulsado el widget ya colocado → **Editar widget → Diseño**.

Para que salgan en el coche: **Ajustes → General → CarPlay → tu coche → Personalizar**.
Con el coche conectado, mantén pulsado el widget del panel y elige *Carplayinit*.

Sin coche delante se prueban con el **CarPlay Simulator** de Xcode: *Open Developer Tool →
Simulator*, y allí *I/O → External Displays → CarPlay*.

### El sonido

1. Pestaña **Sonidos**: ▶︎ para escuchar, el círculo de la derecha para dejarlo elegido.
2. **Importar un audio** trae cualquier `.m4a` o `.mp3` de la app Archivos. Se abre el
   recortador, eliges el trozo, lo escuchas y lo guardas. Los temas de Apple Music llevan
   DRM y no se pueden importar.
3. **Escribir lo que diga** genera el sonido a partir de un texto: eliges voz y
   velocidad, lo escuchas y lo guardas.
4. **Ajustes → Volumen** y *Probar ahora*, para oírlo sin salir de casa.

¿Sacar el audio de un vídeo, sin apps de terceros? Guarda el vídeo en Fotos y crea un
atajo con **Codificar contenido multimedia → Sólo audio: sí**: deja un `.m4a` en Archivos
listo para importar.

### Para que suene con la app cerrada

Hay dos vías y conviene tener las dos:

- **Ajustes → Mantener a la escucha**: la app sigue atenta en segundo plano. Gasta batería.
- **Ajustes → Automatización con Atajos**: una automatización *Al conectar CarPlay →
  Reproducir sonido de arranque*. Se dispara aunque Carplayinit lleve días sin abrirse.
  Es la opción a prueba de balas.

---

## Cómo funciona por dentro

### El sonido de arranque, sin humo

No existe API pública para sustituir el aviso de conexión de CarPlay: **el de Apple suena
siempre primero**. Lo que hace Carplayinit es reconocer el momento en que el móvil entra
en el coche y colocar el clip justo detrás.

`CarConnectionWatcher` escucha `AVAudioSession.routeChangeNotification` y mira si la salida
ha pasado a ser `.carAudio` (CarPlay) o Bluetooth A2DP/HFP. Con *Mantener a la escucha*
activado, un bucle de silencio mantiene viva la sesión de audio en segundo plano, que es
lo que permite oír ese cambio de ruta horas después de haber cerrado la app. Eso cuesta
batería, y por eso es un ajuste y no un comportamiento impuesto: apagado, el sonido suena
cuando la app ya está en marcha, y para el resto está la automatización de Atajos.

Entre la conexión y el clip hay 900 ms de espera a propósito. La unidad de a bordo necesita
un respiro después del *handshake* o se come las primeras notas.

### Las voces

`AVSpeechSynthesizer.write` devuelve PCM en vez de reproducirlo, y eso es lo que
permite que un texto hablado pase por la misma cadena que cualquier importación:
recorte, fundidos y −12 dBFS.

Qué voz suene depende de las que tenga instaladas el iPhone: por defecto se elige la
mejor voz española del género pedido —calidad primero, castellano antes que las
variantes latinoamericanas— y si no hay ninguna de ese género se usa la que haya. Pero
la heurística no manda: en la propia pantalla se puede fijar una voz concreta, porque
cuál suena bien es cuestión de gusto y no de ranking. La elección se recuerda por
carácter, y debajo se ve siempre cuál está sonando.

**El tono no es fijo, depende de la voz que salga.** Midiendo la frecuencia
fundamental del audio ya renderizado: bajar una voz femenina para que suene masculina
se queda en unos 138 Hz aun forzando el `pitchMultiplier` a su mínimo de 0.5 —zona
ambigua—, mientras que ese mismo 0.5 aplicado a una voz masculina de verdad, que ya
ronda los 115 Hz, la manda al terreno del dibujo animado. Así que una voz del género
correcto recibe un empujón (0.90 / 1.34) y una sustituta recibe todo lo disponible
(0.50 / 1.60).

Los valores se eligieron de oído sobre una tanda de variantes renderizadas y medidas.
La femenina son ≈245 Hz: la versión aterciopelada de ≈180 Hz se descartó porque, sobre
ruido de motor, la brillante se abre paso mejor.

### Los chimes están sintetizados, no grabados

`ChimeSynth` los genera con osciladores y envolventes, y `ChimeRecipes` los describe como
datos: añadir un chime es añadir una receta, no escribir código. Se renderizan una sola vez
al primer arranque y quedan cacheados en el contenedor compartido.

Dos motivos para hacerlo así: todo lo que suena es nuestro para licenciarlo, y un chime
generado se afina — tono, longitud, brillo — sin pasar por un DAW.

### Los widgets

`CarWidgetCard` es la misma vista que renderiza la extensión y que dibuja la vista previa
del editor, así que no hay hueco entre lo que diseñas y lo que aparece en el salpicadero.
CarPlay los pinta en estilo StandBy — `systemSmall`, a todo color y **sin fondo de
contenedor** —, por eso la tarjeta pinta su propio fondo y redondea sus propias esquinas.

La línea de tiempo tiene una sola entrada con política `.never`: el dibujo es estático y la
hora, cuando se muestra, se refresca sola con `Text(style:)` sin gastar recargas.

---

## El clip de arranque propio

```bash
Tools/prepare_clip.sh ~/Downloads/mi-audio.mp3 [inicio] [duración]
```

Lo pasa a mono, recorta, pone fundidos, lo nivela a −12 dBFS y lo deja en
`Carplayinit/Resources/startup-clip.m4a`. Sin inicio ni duración coge el archivo **entero**:
el límite de 60 s del importador de la app no aplica a un clip que viaja dentro del bundle.
Con `Tools/prepare_clip.sh mi-audio.mp3 3 4` te quedas con cuatro segundos a partir del
tercero.

Si el archivo está, una fase de build lo copia al bundle y aparece en la app como pack
*Destacado*, ya elegido. Si no está, avisa por consola y la app tira de los chimes
sintetizados. No hay que tocar el proyecto en ninguno de los dos casos.

`Carplayinit/Resources/` está en el `.gitignore` a propósito: este repo es público y esa
grabación no es nuestra para redistribuirla.

## Los emblemas

Tampoco viajan aquí los logos de las marcas, que son marcas registradas. Cuando falta el
asset, `BrandMark` dibuja un monograma con las iniciales sobre el color corporativo — que
es lo que se ve ahora mismo. Para ponerlos basta con arrastrar un PNG al catálogo, sin
tocar código: instrucciones en `Brands/README.md`.

## El icono

No está dibujado a mano: lo genera `Tools/make_icon.swift`, por la misma razón
que los chimes se sintetizan — afinar el color o la composición es cambiar un número.

```bash
swift Tools/make_icon.swift Carplayinit/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

Un 1024×1024 en sRGB **sin canal alfa**, que App Store no admite transparencia. De ese
único PNG salen todos los tamaños del catálogo. Necesita el Xcode completo delante
(`DEVELOPER_DIR`), no las Command Line Tools.

---

## Estructura

```
Carplayinit/
├── Carplayinit.xcodeproj        # generado por Tools/generate_project.rb
├── Carplayinit/                 # target principal
│   ├── CarplayinitApp.swift
│   ├── Model/
│   │   ├── Garage.swift              # coches y diseños, sobre el App Group
│   │   ├── GarageSeed.swift          # los tres coches precargados
│   │   └── LegacyMigration.swift     # rescate de los datos de la versión «Ignition»
│   ├── Audio/
│   │   ├── CarConnectionWatcher.swift # detección de coche + keep-alive
│   │   ├── StartupSoundPlayer.swift
│   │   ├── ChimeSynth.swift           # síntesis y escritura WAV
│   │   ├── ChimeRecipes.swift         # los 24 chimes, como datos
│   │   ├── SpeechSynth.swift          # texto a voz, con las dos voces
│   │   ├── AudioNormalizer.swift      # import, recorte, −12 dBFS, mezcla
│   │   └── SoundLibrary.swift
│   ├── Intents/StartupSoundIntents.swift
│   └── Views/                   # garaje, editor de coche, editor de widget, sonidos, ajustes
├── CarplayinitWidget/           # extensión WidgetKit
├── Shared/                      # compilado en AMBOS targets
│   ├── brands.json                    # catálogo de marcas, recurso de los dos bundles
│   ├── Brand.swift  VehicleProfile.swift  WidgetDesign.swift  StartupSound.swift
│   ├── SharedStore.swift              # App Group: group.Altamirano.Carplayinit
│   ├── CarWidgetCard.swift            # la vista del widget, compartida con la previa
│   └── ColorHex.swift  SelectDesignIntent.swift
├── Brands/Brands.xcassets       # huecos para los emblemas
└── Tools/                       # generate_project.rb · prepare_clip.sh · make_icon.swift
```

`Shared/` se compila en los dos targets porque una extensión no puede leer los recursos de
la app que la contiene: `brands.json` y el catálogo de emblemas se copian a ambos bundles.

Los valores pequeños viven en el `UserDefaults` del App Group; los binarios (fotos de los
coches, audio importado) en el contenedor, para que la extensión los lea sin copiarlos.

## Compilar

```bash
ruby Tools/generate_project.rb     # regenera Carplayinit.xcodeproj desde el árbol
open Carplayinit.xcodeproj
```

El `.xcodeproj` está generado, no editado a mano: añadir un archivo Swift es dejarlo en su
carpeta y volver a ejecutar el script. Compila con concurrencia estricta completa.

Las *capabilities* ya vienen puestas en los entitlements: **App Groups**
(`group.Altamirano.Carplayinit`) en los dos targets y **Background Modes → Audio** en la app.

## Venías de Ignition

Esta app se llamó Ignition. El renombrado cambió el App Group, y para iOS un grupo distinto
es otro contenedor — con el garaje, las fotos y los sonidos importados dentro. Por eso la
app declara también `group.Altamirano.Ignition`: `LegacyMigration` copia todo eso la primera
vez que arranca y no vuelve a tocarlo nunca más.

Si nunca tuviste Ignition instalada no hay nada que copiar, y puedes borrar esa línea de
`Carplayinit/Carplayinit.entitlements`.
