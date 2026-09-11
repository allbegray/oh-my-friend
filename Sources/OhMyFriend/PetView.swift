import AppKit
import SceneKit

public protocol PetViewDelegate: AnyObject {
    func petViewDidClick(_ view: PetView)
    func petViewDidStartDrag(_ view: PetView, at screenPoint: CGPoint)
    func petViewDidDrag(_ view: PetView, to screenPoint: CGPoint)
    func petViewDidEndDrag(_ view: PetView, throwVelocity: CGPoint)
}

public final class PetView: SCNView {
    public weak var petDelegate: PetViewDelegate?
    public let petNode: PetNode

    private var isDragging: Bool = false
    private var lastDragPos: CGPoint = .zero
    private var lastDragTime: TimeInterval = 0
    private var dragVelocity: CGPoint = .zero

    public init(frame: NSRect, kind: PetKind = .wolf) {
        self.petNode = PetNode(kind: kind)
        super.init(frame: frame, options: nil)
        setupScene()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScene() {
        let (scene, stage) = makeStage(cameraY: 0.8, cameraZ: 3.8, fov: 36.0, pitch: -0.08)
        self.scene = scene
        configure(self)

        // Pet body centered (Y = 0.6), feet at Y = 0
        petNode.position = SCNVector3(0, 0, 0)
        stage.addChildNode(petNode)
        StageBrightness.apply(to: scene)
    }

    // MARK: - Mouse Events
    public override func mouseDown(with event: NSEvent) {
        let mouseScreen = NSEvent.mouseLocation
        isDragging = true
        lastDragPos = mouseScreen
        lastDragTime = ProcessInfo.processInfo.systemUptime
        dragVelocity = .zero

        petDelegate?.petViewDidStartDrag(self, at: mouseScreen)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let currentMouse = NSEvent.mouseLocation
        let currentTime = ProcessInfo.processInfo.systemUptime
        let dt = currentTime - lastDragTime

        if dt > 0.001 {
            let instantVx = (currentMouse.x - lastDragPos.x) / CGFloat(dt)
            let instantVy = (currentMouse.y - lastDragPos.y) / CGFloat(dt)
            dragVelocity = CGPoint(
                x: dragVelocity.x * 0.4 + instantVx * 0.6,
                y: dragVelocity.y * 0.4 + instantVy * 0.6
            )
        }

        lastDragPos = currentMouse
        lastDragTime = currentTime
        petDelegate?.petViewDidDrag(self, to: currentMouse)
    }

    public override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false

        if event.clickCount == 1 && hypot(dragVelocity.x, dragVelocity.y) < 50.0 {
            // Click!
            petDelegate?.petViewDidClick(self)
        } else {
            let maxSpeed: CGFloat = 600.0
            let throwV = CGPoint(
                x: max(-maxSpeed, min(maxSpeed, dragVelocity.x)),
                y: max(-maxSpeed, min(maxSpeed, dragVelocity.y))
            )
            petDelegate?.petViewDidEndDrag(self, throwVelocity: throwV)
        }
    }
}
