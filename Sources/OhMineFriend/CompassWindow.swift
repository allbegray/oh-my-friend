import AppKit
import CoreGraphics
import Foundation

public final class SpawnCompass {
    public static let shared = SpawnCompass()

    private static let spawnXKey = "SpawnCompass.spawnX"
    private static let spawnYKey = "SpawnCompass.spawnY"
    private static let hasSpawnKey = "SpawnCompass.hasSpawn"

    public var spawnPoint: CGPoint?

    private init() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.hasSpawnKey) {
            let x = defaults.double(forKey: Self.spawnXKey)
            let y = defaults.double(forKey: Self.spawnYKey)
            spawnPoint = CGPoint(x: x, y: y)
        } else {
            spawnPoint = nil
        }
    }

    public func setSpawn(_ pos: CGPoint) {
        spawnPoint = pos
        let defaults = UserDefaults.standard
        defaults.set(pos.x, forKey: Self.spawnXKey)
        defaults.set(pos.y, forKey: Self.spawnYKey)
        defaults.set(true, forKey: Self.hasSpawnKey)
    }

    public func recallMessage(petCount: Int, buddyCount: Int) -> String {
        let pets = max(0, petCount)
        let buddies = max(0, buddyCount)
        if pets == 0 && buddies == 0 {
            return "🧭 돌아올 펫·친구가 없어요"
        }
        return "🧭 펫 \(pets)마리·친구 \(buddies)기 귀환!"
    }
}

public final class CompassToastWindow: EntityWindow {
    private let message: String

    public init(message: String, at pos: CGPoint) {
        self.message = message
        let size = NSSize(width: 220, height: 64)
        super.init(contentRect: NSRect(x: pos.x - size.width / 2.0, y: pos.y, width: size.width, height: size.height), ignoresMouse: true)
        contentView = CompassToastDrawView(
            frame: NSRect(origin: .zero, size: size),
            message: message
        )
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.close()
        }
    }
}

private final class CompassToastDrawView: NSView {
    private let message: String

    init(frame: NSRect, message: String) {
        self.message = message
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        self.message = ""
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.85)
        ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: w, height: h))
        let cx: CGFloat = 28
        let cy: CGFloat = 32
        let r: CGFloat = 18
        ctx.setFillColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.setFillColor(red: 0.90, green: 0.20, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 4, y: cy, width: 8, height: 14))
        ctx.fill(CGRect(x: cx - 6, y: cy + 10, width: 12, height: 4))
        ctx.setFillColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 4, y: cy - 14, width: 8, height: 14))
        ctx.fill(CGRect(x: cx - 6, y: cy - 14, width: 12, height: 4))
        ctx.setFillColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6))
        let text = message as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white
        ]
        text.draw(at: NSPoint(x: 54, y: 24), withAttributes: attrs)
    }
}
