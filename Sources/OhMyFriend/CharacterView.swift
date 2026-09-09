import AppKit
import SceneKit
import UniformTypeIdentifiers

public protocol CharacterViewDelegate: AnyObject {
    func characterViewDidStartDrag(_ view: CharacterView, at screenPoint: CGPoint)
    func characterViewDidDrag(_ view: CharacterView, to screenPoint: CGPoint)
    func characterViewDidEndDrag(_ view: CharacterView, throwVelocity: CGPoint)
    func characterViewDidRequestMenu(_ view: CharacterView, at event: NSEvent)
    func characterViewDidLoadSkinFile(_ view: CharacterView, url: URL)
}

public final class CharacterView: SCNView {
    public weak var characterDelegate: CharacterViewDelegate?
    public let characterNode = MinecraftCharacterNode()

    private var isDraggingCharacter: Bool = false
    private var dragStartMousePos: CGPoint = .zero
    private var lastDragPos: CGPoint = .zero
    private var lastDragTime: TimeInterval = 0
    private var dragVelocity: CGPoint = .zero

    public init(frame: NSRect, skin: SkinTexture) {
        super.init(frame: frame, options: nil)
        setupScene()
        characterNode.applySkin(skin)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScene() {
        backgroundColor = .clear
        rendersContinuously = true
        antialiasingMode = .none // crisp retro pixels

        let scene = SCNScene()
        self.scene = scene

        // 1. Add Character Node
        // Minecraft character height: ~3.2 units (Legs 1.2 + Torso 1.2 + Head 0.8)
        // Feet are at Y = 0
        characterNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(characterNode)

        // 2. Camera: Positioned so character is centered nicely in 160x160 viewport
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.fieldOfView = 36.0
        cameraNode.camera = camera
        // Center camera slightly above waist (Y = 1.6), looking slightly downward
        cameraNode.position = SCNVector3(0, 2.0, 6.2)
        cameraNode.eulerAngles = SCNVector3(-0.06, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // 3. Lighting: Soft ambient + crisp directional light from top-front-right
        let ambientNode = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(white: 0.65, alpha: 1.0)
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let dirLightNode = SCNNode()
        let dirLight = SCNLight()
        dirLight.type = .directional
        dirLight.color = NSColor(white: 0.75, alpha: 1.0)
        dirLightNode.light = dirLight
        dirLightNode.position = SCNVector3(3, 7, 5)
        dirLightNode.eulerAngles = SCNVector3(-0.8, 0.5, 0)
        scene.rootNode.addChildNode(dirLightNode)
    }

    // MARK: - Mouse Drag & Interactivity
    public override func mouseDown(with event: NSEvent) {
        let mouseScreen = NSEvent.mouseLocation
        isDraggingCharacter = true
        dragStartMousePos = mouseScreen
        lastDragPos = mouseScreen
        lastDragTime = ProcessInfo.processInfo.systemUptime
        dragVelocity = .zero

        characterDelegate?.characterViewDidStartDrag(self, at: mouseScreen)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDraggingCharacter else { return }
        let currentMouse = NSEvent.mouseLocation
        let currentTime = ProcessInfo.processInfo.systemUptime
        let dt = currentTime - lastDragTime

        if dt > 0 {
            let instantVx = (currentMouse.x - lastDragPos.x) / CGFloat(dt)
            let instantVy = (currentMouse.y - lastDragPos.y) / CGFloat(dt)
            dragVelocity = CGPoint(
                x: dragVelocity.x * 0.4 + instantVx * 0.6,
                y: dragVelocity.y * 0.4 + instantVy * 0.6
            )
        }

        lastDragPos = currentMouse
        lastDragTime = currentTime

        characterDelegate?.characterViewDidDrag(self, to: currentMouse)
    }

    public override func mouseUp(with event: NSEvent) {
        guard isDraggingCharacter else { return }
        isDraggingCharacter = false

        // Throw velocity with clamp
        let maxSpeed: CGFloat = 800.0
        let throwV = CGPoint(
            x: max(-maxSpeed, min(maxSpeed, dragVelocity.x)),
            y: max(-maxSpeed, min(maxSpeed, dragVelocity.y))
        )

        characterDelegate?.characterViewDidEndDrag(self, throwVelocity: throwV)
    }

    public override func rightMouseDown(with event: NSEvent) {
        characterDelegate?.characterViewDidRequestMenu(self, at: event)
    }

    // MARK: - Drag and Drop Skin PNG Support
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let board = sender.draggingPasteboard.propertyList(forType: .fileURL) as? String,
           let url = URL(string: board),
           url.pathExtension.lowercased() == "png" {
            return .copy
        }
        return []
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let items = sender.draggingPasteboard.pasteboardItems else { return false }
        for item in items {
            if let stringURL = item.string(forType: .fileURL),
               let url = URL(string: stringURL),
               url.pathExtension.lowercased() == "png" {
                characterDelegate?.characterViewDidLoadSkinFile(self, url: url)
                return true
            }
        }
        return false
    }
}
