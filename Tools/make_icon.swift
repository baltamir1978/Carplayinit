// Dibuja el icono de la app: Carplayinit/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
//   swift Tools/make_icon.swift Carplayinit/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
// Generado y no dibujado a mano por la misma razón que los chimes: así se puede
// afinar el color o la composición sin abrir un editor de imágenes. Necesita el
// Xcode completo delante (DEVELOPER_DIR), no las Command Line Tools.
import AppKit

let side = 1024.0
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

// Sin canal alfa: App Store rechaza un icono con transparencia.
guard let ctx = CGContext(data: nil, width: Int(side), height: Int(side),
                          bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("no context")
}

// El verde del Defender, que es el coche que dio pie a todo esto.
let gradient = CGGradient(colorsSpace: sRGB, colors: [
    CGColor(red: 0.322, green: 0.396, blue: 0.286, alpha: 1),  // #52654A
    CGColor(red: 0.067, green: 0.082, blue: 0.051, alpha: 1)   // #11150D
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: side),
                       end: CGPoint(x: side, y: 0), options: [])

// Un brillo suave arriba a la izquierda: el mismo truco que usa PaintFinishBackground
// para que una superficie plana no parezca cartón.
let sheen = CGGradient(colorsSpace: sRGB, colors: [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0)
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: side * 0.26, y: side * 0.84),
                       startRadius: 0, endCenter: CGPoint(x: side * 0.26, y: side * 0.84),
                       endRadius: side * 0.66, options: [])

/// Tiñe el símbolo en su propio contexto —que sí tiene alfa— antes de bajarlo al
/// lienzo opaco: un `sourceAtop` sobre un contexto sin alfa pinta el rectángulo entero.
func tinted(_ name: String, weight: NSFont.Weight, size: CGFloat, alpha: CGFloat) -> NSImage? {
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil),
          let sized = symbol.withSymbolConfiguration(.init(pointSize: size, weight: weight))
    else { return nil }
    let image = NSImage(size: sized.size)
    image.lockFocus()
    sized.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor(white: 0.97, alpha: alpha).set()
    NSRect(origin: .zero, size: sized.size).fill(using: .sourceAtop)
    image.unlockFocus()
    return image
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

func place(_ image: NSImage?, centeredAt center: CGPoint) {
    guard let image else { return }
    let box = image.size
    image.draw(in: CGRect(x: center.x - box.width / 2, y: center.y - box.height / 2,
                          width: box.width, height: box.height),
               from: .zero, operation: .sourceOver, fraction: 1)
}

// Las ondas son el sonido de arranque; el coche, los widgets. La app es las dos
// cosas y el icono tiene que decirlo a 40 px, así que van separadas, no superpuestas.
place(tinted("car.fill", weight: .medium, size: 430, alpha: 1),
      centeredAt: CGPoint(x: side / 2, y: side * 0.585))
place(tinted("waveform", weight: .semibold, size: 215, alpha: 0.62),
      centeredAt: CGPoint(x: side / 2, y: side * 0.265))

NSGraphicsContext.restoreGraphicsState()

guard let image = ctx.makeImage() else { fatalError("no image") }
let rep = NSBitmapImageRep(cgImage: image)
rep.size = NSSize(width: side, height: side)
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("escrito")
