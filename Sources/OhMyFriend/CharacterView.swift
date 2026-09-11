import AppKit
import SceneKit
import UniformTypeIdentifiers

public protocol CharacterViewDelegate: AnyObject {
    func characterViewDidStartDrag(_ view: CharacterView, at screenPoint: CGPoint)
    func characterViewDidDrag(_ view: CharacterView, to screenPoint: CGPoint)
    func characterViewDidEndDrag(_ view: CharacterView, throwVelocity: CGPoint)
    func characterViewDidRequestMenu(_ view: CharacterView, at event: NSEvent)
    func characterViewDidLoadSkinFile(_ view: CharacterView, url: URL)
    func characterViewDidClick(_ view: CharacterView)
    func characterViewDidDoubleClick(_ view: CharacterView)
}

public final class CharacterView: SCNView {
    public weak var characterDelegate: CharacterViewDelegate?
    public let characterNode = MinecraftCharacterNode()

    private var isDraggingCharacter: Bool = false

    /// 놓는 순간의 '던지기 속도' 계산용 최근 이동 샘플 (시간, 화면 좌표)
    private var dragSamples: [(t: TimeInterval, p: CGPoint)] = []

    /// 속도 관측 창(초). 마지막 이동이 이보다 오래됐다면 멈춰서 놓은 것으로 본다.
    private static let throwVelocityWindow: TimeInterval = 0.09
    private static let throwVelocityMaxSpeed: CGFloat = 800.0

    /// 최근 드래그 샘플로 던지기 속도를 구한다.
    /// 관측 창 안에 이동 샘플이 없으면(= 마지막 이동이 오래됐으면) 0을 돌려주어 '던지기'가 아니라 '놓기'로 취급된다.
    public static func throwVelocity(from samples: [(t: TimeInterval, p: CGPoint)], now: TimeInterval) -> CGPoint {
        let recent = samples.filter { now - $0.t <= throwVelocityWindow }
        guard let first = recent.first, let last = recent.last else { return .zero }
        let dt = last.t - first.t
        guard dt >= 0.005 else { return .zero }
        let vx = (last.p.x - first.p.x) / CGFloat(dt)
        let vy = (last.p.y - first.p.y) / CGFloat(dt)
        return CGPoint(
            x: max(-throwVelocityMaxSpeed, min(throwVelocityMaxSpeed, vx)),
            y: max(-throwVelocityMaxSpeed, min(throwVelocityMaxSpeed, vy))
        )
    }

    public init(frame: NSRect, skin: SkinTexture) {
        super.init(frame: frame, options: nil)
        setupScene()
        characterNode.applySkin(skin)
        if let scene = scene {
            StageBrightness.apply(to: scene)
        }
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScene() {
        let (scene, stage) = makeStage(cameraY: 2.15, cameraZ: 7.1, fov: 36.0, pitch: -0.06)
        self.scene = scene
        configure(self)

        // 1. Add Character Node
        // Minecraft character height: ~3.2 units (Legs 1.2 + Torso 1.2 + Head 0.8)
        // Feet are at Y = 0
        characterNode.position = SCNVector3(0, 0, 0)
        stage.addChildNode(characterNode)
    }

    // MARK: - Mouse Drag & Interactivity
    public override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            characterDelegate?.characterViewDidDoubleClick(self)
        } else {
            characterDelegate?.characterViewDidClick(self)
        }

        let mouseScreen = NSEvent.mouseLocation
        isDraggingCharacter = true
        dragSamples = [(ProcessInfo.processInfo.systemUptime, mouseScreen)]

        characterDelegate?.characterViewDidStartDrag(self, at: mouseScreen)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDraggingCharacter else { return }
        let currentMouse = NSEvent.mouseLocation
        let now = ProcessInfo.processInfo.systemUptime

        dragSamples.append((now, currentMouse))
        // 관측 창보다 오래된 샘플은 버린다 (메모리 상한 + 정지 판정 정확도)
        let cutoff = now - Self.throwVelocityWindow
        dragSamples.removeAll { $0.t < cutoff }

        characterDelegate?.characterViewDidDrag(self, to: currentMouse)
    }

    public override func mouseUp(with event: NSEvent) {
        guard isDraggingCharacter else { return }
        isDraggingCharacter = false

        let throwV = Self.throwVelocity(from: dragSamples, now: ProcessInfo.processInfo.systemUptime)
        dragSamples.removeAll()

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
