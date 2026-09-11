import AppKit
import CoreGraphics
import SceneKit

public enum SlimeSize: CaseIterable {
    case big
    case medium
    case small

    public func smaller() -> SlimeSize? {
        switch self {
        case .big: return .medium
        case .medium: return .small
        case .small: return nil
        }
    }

    public var hitPoints: Int {
        switch self {
        case .big: return 3
        case .medium: return 2
        case .small: return 1
        }
    }

    public var panelSize: CGFloat {
        switch self {
        case .big: return 96
        case .medium: return 64
        case .small: return 40
        }
    }

    /// 원작 히트박스(2.08 / 1.04 / 0.52 블록)에 맞춘 복셀 한 변(블록).
    public var cubeEdge: CGFloat {
        switch self {
        case .big: return 2.0
        case .medium: return 1.0
        case .small: return 0.5
        }
    }

    /// 패널 높이 대비 슬라임이 차지하는 비율. 카메라는 전 몹이 공유하므로, 크기별로 릭을
    /// 확대해 작은 슬라임도 겔 외피와 얼굴이 읽히게 한다. 큰 슬라임이 창을 거의 채우면
    /// 화면에서 부담스러워(2026-09-11 제보) 세 크기를 같은 비율(≈0.85)로 줄였다.
    public var panelFill: CGFloat {
        switch self {
        case .big: return 0.66
        case .medium: return 0.59
        case .small: return 0.56
        }
    }
}

public protocol SlimeWindowDelegate: AnyObject {
    func slimeWindowDidSplit(_ window: SlimeWindow, size: SlimeSize, at pos: CGPoint)
    func slimeWindowDidDespawn(_ window: SlimeWindow)
    func attackSlime(_ slime: SlimeWindow)
}

public final class SlimeWindow: EntityWindow {
    public let slimeSize: SlimeSize
    public private(set) var position: CGPoint
    public weak var slimeDelegate: SlimeWindowDelegate?

    private let rig: SlimeRig
    private var hp: Int
    private var hopTimer: Timer?
    private var hopPhase: CGFloat = 0
    private var direction: CGFloat = 1
    private var wasAirborne = false
    private var isDead = false
    private var lifeTimer: TimeInterval = 0
    private let maxLife: TimeInterval = 12.0

    public init(size: SlimeSize, startPos: CGPoint, delegate: SlimeWindowDelegate) {
        self.slimeSize = size
        self.position = startPos
        self.slimeDelegate = delegate
        self.hp = size.hitPoints
        let s = size.panelSize
        let frame = NSRect(x: startPos.x - s / 2.0, y: startPos.y, width: s, height: s)
        let rig = SlimeRig(size: size.cubeEdge)
        let view = SlimeRig.viewTransform(fill: size.panelFill, edge: size.cubeEdge)
        rig.scale = SCNVector3(view.scale, view.scale, view.scale)
        self.rig = rig
        super.init(contentRect: frame, ignoresMouse: false)
        let sceneView = MobSceneView(frame: NSRect(origin: .zero, size: frame.size))
        sceneView.setCamera(pitch: SlimeRig.viewPitch, cameraY: view.cameraY)
        sceneView.setSubject(rig)
        sceneView.onTap = { [weak self] in
            guard let self = self else { return }
            self.slimeDelegate?.attackSlime(self)
        }
        contentView = sceneView
    }

    public func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        rig.bounce(0.6) // 등장과 함께 젤리가 한 번 출렁인다
        hopTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.step()
        }
        RunLoop.main.add(hopTimer!, forMode: .common)
    }

    /// 한 프레임: 포물선 홉 + 젤리 변형(공중에서 늘어나고 착지에서 튕긴다).
    private func step() {
        hopPhase += 1.0 / 60.0
        if Int(hopPhase * 2.0) % 4 == 0 && Int(hopPhase * 60.0) % 60 == 0 {
            direction = Bool.random() ? 1 : -1
        }
        let hopCycle = hopPhase.truncatingRemainder(dividingBy: 0.9)
        let airborne = hopCycle < 0.45
        let hopHeight: CGFloat = airborne ? sin(hopCycle / 0.45 * CGFloat.pi) * 26.0 : 0
        if airborne {
            position.x += direction * 55.0 / 60.0
        }
        let s = slimeSize.panelSize
        setFrameOrigin(NSPoint(x: position.x - s / 2.0, y: position.y + hopHeight))
        rig.stretch(airborne ? 1.0 : 0.0)
        if wasAirborne && !airborne {
            rig.bounce(1.0) // 착지 충격 → 젤리 진동
        }
        wasAirborne = airborne
        rig.update(dt: 1.0 / 60.0)
        lifeTimer += 1.0 / 60.0
        if lifeTimer >= maxLife {
            despawnNaturally()
        }
    }

    private func despawnNaturally() {
        guard !isDead else { return }
        isDead = true
        hopTimer?.invalidate()
        hopTimer = nil
        SoundAndEffectsManager.shared.play(.pop)
        slimeDelegate?.slimeWindowDidDespawn(self)
        close()
    }

    public override func mouseDown(with event: NSEvent) {
        slimeDelegate?.attackSlime(self)
    }

    public func takeHit() {
        guard !isDead else { return }
        hp -= 1
        rig.flash()
        rig.bounce(1.4)
        if hp <= 0 {
            isDead = true
            hopTimer?.invalidate()
            hopTimer = nil
            if slimeSize.smaller() != nil {
                slimeDelegate?.slimeWindowDidSplit(self, size: slimeSize, at: position)
            } else {
                slimeDelegate?.slimeWindowDidDespawn(self)
            }
            close()
        }
    }

    public override func close() {
        hopTimer?.invalidate()
        hopTimer = nil
        super.close()
    }
}
