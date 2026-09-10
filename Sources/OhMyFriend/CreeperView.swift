import AppKit
import SceneKit

public protocol CreeperViewDelegate: AnyObject {
    func creeperViewDidClick(_ view: CreeperView)
    func creeperViewDidStartDrag(_ view: CreeperView, at screenPoint: CGPoint)
    func creeperViewDidDrag(_ view: CreeperView, to screenPoint: CGPoint)
    func creeperViewDidEndDrag(_ view: CreeperView, throwVelocity: CGPoint)
}

public final class CreeperView: SCNView {
    public weak var creeperDelegate: CreeperViewDelegate?
    public let creeperNode = CreeperNode()

    private var isDragging: Bool = false
    private var lastDragPos: CGPoint = .zero
    private var lastDragTime: TimeInterval = 0
    private var dragVelocity: CGPoint = .zero

    public override init(frame: NSRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        setupScene()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScene() {
        backgroundColor = .clear
        rendersContinuously = true
        antialiasingMode = .none

        let scene = SCNScene()
        self.scene = scene

        creeperNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(creeperNode)

        // Camera: centered on Creeper body
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 36.0
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.95, 3.8)
        cameraNode.eulerAngles = SCNVector3(-0.06, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Ambient & Directional Lighting
        let ambientNode = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(white: 0.70, alpha: 1.0)
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let dirLightNode = SCNNode()
        let dirLight = SCNLight()
        dirLight.type = .directional
        dirLight.color = NSColor(white: 0.75, alpha: 1.0)
        dirLightNode.light = dirLight
        dirLightNode.position = SCNVector3(2, 5, 4)
        dirLightNode.eulerAngles = SCNVector3(-0.7, 0.4, 0)
        scene.rootNode.addChildNode(dirLightNode)
    }

    // MARK: - Mouse Interaction
    public override func mouseDown(with event: NSEvent) {
        let mouseScreen = NSEvent.mouseLocation
        isDragging = true
        lastDragPos = mouseScreen
        lastDragTime = ProcessInfo.processInfo.systemUptime
        dragVelocity = .zero

        creeperDelegate?.creeperViewDidStartDrag(self, at: mouseScreen)
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
        creeperDelegate?.creeperViewDidDrag(self, to: currentMouse)
    }

    public override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false

        if event.clickCount == 1 && hypot(dragVelocity.x, dragVelocity.y) < 50.0 {
            // Clicked Creeper to attack!
            creeperDelegate?.creeperViewDidClick(self)
        } else {
            let maxSpeed: CGFloat = 600.0
            let throwV = CGPoint(
                x: max(-maxSpeed, min(maxSpeed, dragVelocity.x)),
                y: max(-maxSpeed, min(maxSpeed, dragVelocity.y))
            )
            creeperDelegate?.creeperViewDidEndDrag(self, throwVelocity: throwV)
        }
    }
}
