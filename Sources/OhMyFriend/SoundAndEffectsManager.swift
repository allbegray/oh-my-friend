import AppKit

public enum SoundEffect {
    case pop       // Block break / item popup
    case jump      // Jump / Backflip
    case land      // Heavy landing
    case eat       // Eating food
    case heart     // Interaction / Click
    case alert     // Wake up / surprise
    case ignite    // TNT ignition (flint & steel spark)
    case explode   // TNT explosion boom
}

public final class SoundAndEffectsManager {
    public static let shared = SoundAndEffectsManager()

    public var isSoundEnabled: Bool = true

    private var popSound: NSSound?
    private var tinkSound: NSSound?
    private var bottleSound: NSSound?
    private var purrSound: NSSound?
    private var heroSound: NSSound?
    private var pingSound: NSSound?
    private var bassoSound: NSSound?

    private init() {
        popSound = NSSound(named: "Pop")
        tinkSound = NSSound(named: "Tink")
        bottleSound = NSSound(named: "Bottle")
        purrSound = NSSound(named: "Purr")
        heroSound = NSSound(named: "Hero")
        pingSound = NSSound(named: "Ping")
        bassoSound = NSSound(named: "Basso")
    }

    public func play(_ sfx: SoundEffect) {
        guard isSoundEnabled else { return }

        switch sfx {
        case .pop:
            popSound?.stop()
            popSound?.play()
        case .jump:
            tinkSound?.stop()
            tinkSound?.play()
        case .land:
            bottleSound?.stop()
            bottleSound?.play()
        case .eat:
            purrSound?.stop()
            purrSound?.play()
        case .heart:
            heroSound?.stop()
            heroSound?.play()
        case .alert:
            pingSound?.stop()
            pingSound?.play()
        case .ignite:
            tinkSound?.stop()
            tinkSound?.play()
        case .explode:
            bassoSound?.stop()
            bassoSound?.play()
        }
    }
}
