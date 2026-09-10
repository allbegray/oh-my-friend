import AppKit
import CoreGraphics

public final class LeadLineWindow: NSPanel {
    private var petPos: CGPoint
    private var anchorPos: CGPoint
    private var lineView: LeadLineView?

    public init(petPos: CGPoint, anchorPos: CGPoint) {
        self.petPos = petPos
        self.anchorPos = anchorPos
        super.init(
            contentRect: LeadLineWindow.frameFor(petPos: petPos, anchorPos: anchorPos),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = LeadLineView(frame: NSRect(origin: .zero, size: frame.size))
        view.update(petLocal: petPos.minus(origin: frame.origin), anchorLocal: anchorPos.minus(origin: frame.origin))
        self.lineView = view
        contentView = view
    }

    public func update(petPos: CGPoint, anchorPos: CGPoint) {
        self.petPos = petPos
        self.anchorPos = anchorPos
        let newFrame = LeadLineWindow.frameFor(petPos: petPos, anchorPos: anchorPos)
        setFrame(newFrame, display: false)
        lineView?.frame = NSRect(origin: .zero, size: newFrame.size)
        lineView?.update(
            petLocal: petPos.minus(origin: newFrame.origin),
            anchorLocal: anchorPos.minus(origin: newFrame.origin)
        )
        lineView?.needsDisplay = true
    }

    public func place() {
        orderFrontRegardless()
    }

    private static func frameFor(petPos: CGPoint, anchorPos: CGPoint) -> NSRect {
        let margin: CGFloat = 8.0
        let minX = min(petPos.x, anchorPos.x) - margin
        let minY = min(petPos.y, anchorPos.y) - margin
        let maxX = max(petPos.x, anchorPos.x) + margin
        let maxY = max(petPos.y, anchorPos.y) + margin
        return NSRect(x: minX, y: minY, width: max(maxX - minX, 4.0), height: max(maxY - minY, 4.0))
    }
}

private final class LeadLineView: NSView {
    private var petLocal: CGPoint = .zero
    private var anchorLocal: CGPoint = .zero

    func update(petLocal: CGPoint, anchorLocal: CGPoint) {
        self.petLocal = petLocal
        self.anchorLocal = anchorLocal
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setStrokeColor(red: 0.4, green: 0.28, blue: 0.15, alpha: 1.0)
        ctx.setLineWidth(2.0)
        ctx.setLineCap(.round)
        ctx.move(to: anchorLocal)
        ctx.addLine(to: petLocal)
        ctx.strokePath()
    }
}

private extension CGPoint {
    func minus(origin: CGPoint) -> CGPoint {
        CGPoint(x: x - origin.x, y: y - origin.y)
    }
}

public final class LeadManager {
    public static let shared = LeadManager()

    private var window: LeadLineWindow?

    private init() {}

    public var isTied: Bool {
        window != nil
    }

    public func tie(petPos: CGPoint, anchorPos: CGPoint) {
        untie()
        let panel = LeadLineWindow(petPos: petPos, anchorPos: anchorPos)
        window = panel
        panel.orderFrontRegardless()
    }

    public func untie() {
        window?.close()
        window = nil
    }

    public func update(petPos: CGPoint, anchorPos: CGPoint) {
        window?.update(petPos: petPos, anchorPos: anchorPos)
    }
}
