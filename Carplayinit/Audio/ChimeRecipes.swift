import Foundation

/// The built-in chime catalog, written as synthesis recipes.
///
/// Kept apart from `ChimeSynth` so adding a chime is a data change, not a code one.
enum ChimeRecipes {
    private static func hz(_ midi: Double) -> Double { ChimeSynth.hz(midi) }

    /// Struck-bell voice: FM with a decaying modulation index.
    private static func bell(_ midi: Double, at start: Double, duration: Double = 1.1,
                             gain: Double = 1) -> ChimeSynth.Voice {
        ChimeSynth.Voice(start: start, duration: duration, frequency: hz(midi),
                         waveform: .fm(ratio: 2.01, index: 3.2), gain: gain,
                         attack: 0.004, release: duration * 0.85)
    }

    private static func pad(_ midi: Double, at start: Double, duration: Double,
                            gain: Double = 0.7) -> ChimeSynth.Voice {
        ChimeSynth.Voice(start: start, duration: duration, frequency: hz(midi),
                         waveform: .triangle, gain: gain, attack: 0.12, release: duration * 0.6)
    }

    private static func sweep(from: Double, to: Double, at start: Double, duration: Double,
                              waveform: ChimeSynth.Waveform = .saw,
                              gain: Double = 0.8) -> ChimeSynth.Voice {
        ChimeSynth.Voice(start: start, duration: duration, frequency: from, endFrequency: to,
                         waveform: waveform, gain: gain, attack: 0.01, release: duration * 0.4)
    }

    /// Bugle voice: brass-ish FM, slower attack than a bell.
    private static func bugle(_ midi: Double, at start: Double, duration: Double,
                              gain: Double = 0.8) -> ChimeSynth.Voice {
        ChimeSynth.Voice(start: start, duration: duration, frequency: hz(midi),
                         waveform: .fm(ratio: 1.0, index: 2.4), gain: gain,
                         attack: 0.03, release: duration * 0.35)
    }

    /// Power chord: root, fifth and octave on square waves. Square is all odd
    /// harmonics, which is most of what makes a distorted guitar sound distorted —
    /// close enough without a waveshaper.
    private static func power(_ midi: Double, at start: Double, duration: Double,
                              gain: Double = 0.45) -> [ChimeSynth.Voice] {
        [midi, midi + 7, midi + 12].enumerated().map { index, note in
            ChimeSynth.Voice(start: start, duration: duration, frequency: hz(note),
                             waveform: .square, gain: gain * (index == 0 ? 1 : 0.6),
                             attack: 0.004, release: duration * 0.5)
        }
    }

    private static func blip(_ midi: Double, at start: Double, duration: Double = 0.09,
                             gain: Double = 0.55) -> ChimeSynth.Voice {
        ChimeSynth.Voice(start: start, duration: duration, frequency: hz(midi),
                         waveform: .square, gain: gain, attack: 0.002, release: 0.03)
    }

    // MARK: - Packs

    static let all: [(pack: String, name: String, subtitle: String, symbol: String, recipes: [ChimeSynth.Recipe])] = [
        ("classic", "Clásicos", "Campanas limpias, como las de fábrica", "bell.fill", classic),
        ("sport", "Deportivos", "Barridos de escape y subidas de vueltas", "flame.fill", sport),
        ("electric", "Eléctricos", "Sintéticos, suaves, sin motor", "bolt.fill", electric),
        ("luxury", "Lujo", "Acordes cálidos de salón", "sparkles", luxury),
        ("retro", "Retro", "Bips de 8 bits", "gamecontroller.fill", retro),
        ("engines", "Arranque", "Fanfarria y guitarras, sintetizadas aquí", "flag.checkered", engines)
    ]

    // MARK: Classic

    static let classic: [ChimeSynth.Recipe] = [
        .init(id: "classic-welcome", name: "Bienvenida", packID: "classic", voices: [
            bell(72, at: 0), bell(76, at: 0.10, gain: 0.85), bell(79, at: 0.20, duration: 1.4)
        ]),
        .init(id: "classic-two-note", name: "Dos notas", packID: "classic", voices: [
            bell(67, at: 0, duration: 0.6), bell(72, at: 0.18, duration: 1.2)
        ]),
        .init(id: "classic-single", name: "Campanada", packID: "classic", voices: [
            bell(72, at: 0, duration: 1.6)
        ]),
        .init(id: "classic-rise", name: "Ascenso", packID: "classic", voices: [
            bell(72, at: 0, duration: 0.5, gain: 0.7), bell(74, at: 0.11, duration: 0.5, gain: 0.8),
            bell(76, at: 0.22, duration: 0.6, gain: 0.9), bell(79, at: 0.33, duration: 1.3)
        ])
    ]

    // MARK: Sport

    static let sport: [ChimeSynth.Recipe] = [
        .init(id: "sport-turbo", name: "Turbo", packID: "sport", voices: [
            sweep(from: 160, to: 900, at: 0, duration: 0.7),
            sweep(from: 320, to: 1800, at: 0.05, duration: 0.6, gain: 0.35),
            ChimeSynth.Voice(start: 0.62, duration: 0.35, frequency: 1, waveform: .noise,
                             gain: 0.28, attack: 0.005, release: 0.34)
        ]),
        .init(id: "sport-redline", name: "Corte de vueltas", packID: "sport", voices: [
            blip(76, at: 0, duration: 0.07, gain: 0.6), blip(76, at: 0.10, duration: 0.07, gain: 0.6),
            blip(83, at: 0.20, duration: 0.07, gain: 0.7),
            sweep(from: hz(83), to: hz(95), at: 0.28, duration: 0.5, waveform: .square, gain: 0.5)
        ]),
        .init(id: "sport-launch", name: "Salida", packID: "sport", voices: [
            ChimeSynth.Voice(start: 0, duration: 0.22, frequency: 1, waveform: .noise,
                             gain: 0.35, attack: 0.002, release: 0.2),
            sweep(from: 90, to: 700, at: 0.08, duration: 0.75, gain: 0.9)
        ]),
        .init(id: "sport-downshift", name: "Reducción", packID: "sport", voices: [
            sweep(from: 800, to: 140, at: 0, duration: 0.65, gain: 0.85),
            bell(60, at: 0.55, duration: 0.9, gain: 0.6)
        ])
    ]

    // MARK: Electric

    static let electric: [ChimeSynth.Recipe] = [
        .init(id: "electric-silence", name: "Silencio", packID: "electric", voices: [
            pad(60, at: 0, duration: 1.5), pad(67, at: 0.06, duration: 1.5, gain: 0.5),
            pad(72, at: 0.12, duration: 1.4, gain: 0.3)
        ]),
        .init(id: "electric-impulse", name: "Impulso", packID: "electric", voices: [
            ChimeSynth.Voice(start: 0, duration: 0.9, frequency: hz(55), endFrequency: hz(72),
                             waveform: .triangle, gain: 0.8, attack: 0.05, release: 0.5),
            pad(79, at: 0.35, duration: 0.9, gain: 0.35)
        ]),
        .init(id: "electric-voltage", name: "Voltaje", packID: "electric", voices: [
            ChimeSynth.Voice(start: 0, duration: 0.8, frequency: hz(84),
                             waveform: .fm(ratio: 3.5, index: 4.5), gain: 0.7,
                             attack: 0.003, release: 0.7),
            pad(72, at: 0.1, duration: 1.0, gain: 0.3)
        ]),
        .init(id: "electric-zen", name: "Zen", packID: "electric", voices: [
            ChimeSynth.Voice(start: 0, duration: 1.8, frequency: hz(69), waveform: .sine,
                             gain: 0.7, attack: 0.25, release: 1.2),
            ChimeSynth.Voice(start: 0.3, duration: 1.5, frequency: hz(76), waveform: .sine,
                             gain: 0.35, attack: 0.3, release: 1.1)
        ])
    ]

    // MARK: Luxury

    static let luxury: [ChimeSynth.Recipe] = [
        .init(id: "luxury-crystal", name: "Cristal", packID: "luxury", voices: [
            bell(84, at: 0, duration: 1.3, gain: 0.55), bell(88, at: 0.09, duration: 1.2, gain: 0.4),
            bell(91, at: 0.18, duration: 1.5, gain: 0.3)
        ]),
        .init(id: "luxury-velvet", name: "Terciopelo", packID: "luxury", voices: [
            pad(53, at: 0, duration: 1.6, gain: 0.6), pad(60, at: 0.05, duration: 1.5, gain: 0.45),
            pad(64, at: 0.12, duration: 1.4, gain: 0.35), pad(67, at: 0.2, duration: 1.3, gain: 0.25)
        ]),
        .init(id: "luxury-lounge", name: "Salón", packID: "luxury", voices: [
            bell(65, at: 0, duration: 0.8, gain: 0.6), bell(69, at: 0.14, duration: 0.9, gain: 0.5),
            bell(72, at: 0.28, duration: 1.2, gain: 0.45), pad(53, at: 0, duration: 1.6, gain: 0.3)
        ]),
        .init(id: "luxury-night", name: "Nocturno", packID: "luxury", voices: [
            pad(48, at: 0, duration: 1.8, gain: 0.55),
            bell(75, at: 0.25, duration: 1.4, gain: 0.4),
            bell(70, at: 0.55, duration: 1.2, gain: 0.3)
        ])
    ]

    // MARK: Retro

    static let retro: [ChimeSynth.Recipe] = [
        .init(id: "retro-arcade", name: "Arcade", packID: "retro", voices: [
            blip(72, at: 0), blip(76, at: 0.08), blip(79, at: 0.16), blip(84, at: 0.24, duration: 0.2)
        ]),
        .init(id: "retro-coin", name: "Moneda", packID: "retro", voices: [
            blip(83, at: 0, duration: 0.06), blip(90, at: 0.06, duration: 0.35, gain: 0.5)
        ]),
        .init(id: "retro-powerup", name: "Power up", packID: "retro", voices: [
            blip(60, at: 0), blip(64, at: 0.06), blip(67, at: 0.12), blip(72, at: 0.18),
            blip(76, at: 0.24), blip(79, at: 0.30, duration: 0.3)
        ]),
        .init(id: "retro-boot", name: "Arranque", packID: "retro", voices: [
            ChimeSynth.Voice(start: 0, duration: 0.5, frequency: hz(48), endFrequency: hz(72),
                             waveform: .square, gain: 0.4, attack: 0.005, release: 0.2),
            blip(84, at: 0.5, duration: 0.25, gain: 0.5)
        ])
    ]

    // MARK: Engines

    /// Hand-made stand-ins for the "start your engines" idea: a bugle call over
    /// power chords. Synthesised, so nothing here samples anyone's record.
    static let engines: [ChimeSynth.Recipe] = [
        .init(id: "engines-fanfare", name: "Enciende motores", packID: "engines", voices: [
            // Bugle calls live on the natural harmonics — G, C, E, G reads as one.
            bugle(67, at: 0, duration: 0.22),
            bugle(72, at: 0.20, duration: 0.22),
            bugle(76, at: 0.40, duration: 0.28),
            bugle(79, at: 0.62, duration: 0.55, gain: 0.9)
        ] + power(52, at: 1.05, duration: 0.75, gain: 0.5)),

        .init(id: "engines-riff", name: "Riff", packID: "engines", voices:
            // Alternating staccato chords, the hard-rock intro shape.
            power(45, at: 0.00, duration: 0.13) +
            power(45, at: 0.16, duration: 0.13) +
            power(50, at: 0.32, duration: 0.13) +
            power(45, at: 0.48, duration: 0.13) +
            power(52, at: 0.64, duration: 0.13) +
            power(45, at: 0.80, duration: 0.13) +
            power(50, at: 0.96, duration: 0.42, gain: 0.55)
        ),

        .init(id: "engines-salute", name: "Saludo", packID: "engines", voices: [
            bugle(60, at: 0, duration: 0.3),
            bugle(64, at: 0.26, duration: 0.3),
            bugle(67, at: 0.52, duration: 0.8, gain: 0.9),
            ChimeSynth.Voice(start: 0.52, duration: 0.9, frequency: hz(72),
                             waveform: .fm(ratio: 1.0, index: 1.8), gain: 0.4,
                             attack: 0.05, release: 0.6)
        ]),

        .init(id: "engines-launch", name: "A rodar", packID: "engines", voices:
            power(48, at: 0, duration: 0.5, gain: 0.5) + [
                sweep(from: 110, to: 620, at: 0.35, duration: 0.6, gain: 0.55),
                ChimeSynth.Voice(start: 0.9, duration: 0.3, frequency: 1, waveform: .noise,
                                 gain: 0.22, attack: 0.005, release: 0.29)
            ]
        )
    ]
}
