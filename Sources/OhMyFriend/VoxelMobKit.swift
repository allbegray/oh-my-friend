import AppKit
import SceneKit
import CoreGraphics
import Foundation

// 범용 복셀 몹 킷: 100여 2D 몹의 3D 포팅용 공용 릭 + 뷰.
// 크기 가이드: 1블록 = 1.0 (크리퍼 몸통 0.42, 해골 머리 0.50, 늑대 몸통 0.50x0.50x0.85 기준).
// MobWander 생략: EntityKit.WanderState와 중복되므로 배회는 WanderState.tick(_:)을 사용할 것.

// MARK: - 복셀 박스

/// 복셀 박스 색상: rgb(무광 lambert) / glow(발광 constant+emission).
public enum VoxelColor {
    case rgb(CGFloat, CGFloat, CGFloat)
    case glow(CGFloat, CGFloat, CGFloat)
}

/// VoxelColor를 SCNMaterial로 변환한다.
public func voxelMaterial(_ c: VoxelColor) -> SCNMaterial {
    let m = SCNMaterial()
    switch c {
    case .rgb(let r, let g, let b):
        m.diffuse.contents = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        m.lightingModel = .lambert
    case .glow(let r, let g, let b):
        let col = NSColor(red: r, green: g, blue: b, alpha: 1.0)
        m.diffuse.contents = col
        m.emission.contents = col
        m.lightingModel = .constant
    }
    return m
}

/// 무광 Nearest 느낌의 복셀 박스 노드를 만든다 (glow는 emissive 발광).
public func vbox(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, _ c: VoxelColor) -> SCNNode {
    let box = SCNBox(width: w, height: h, length: d, chamferRadius: 0)
    box.materials = [voxelMaterial(c)]
    return SCNNode(geometry: box)
}

/// 관절 피벗(위쪽 끝)에 아래로伸びる 메쉬를 단 다리/팔 조인트를 만든다.
public func limbJoint(mesh: SCNNode, at position: SCNVector3, drop: CGFloat) -> SCNNode {
    let joint = SCNNode()
    joint.position = position
    mesh.position = SCNVector3(0, drop, 0)
    joint.addChildNode(mesh)
    return joint
}

// MARK: - 4족 릭 (크리퍼/늑대/돼지형)

/// 4족 복셀 릭: 몸통+머리+다리4+꼬리(옵션), walkPhase로 다리 교대 회전.
public final class QuadRig: SCNNode {
    /// 몸통 메쉬 노드.
    public let body = SCNNode()
    /// 머리 조인트 (시선용 yaw/pitch 회전 지점).
    public let head = SCNNode()
    /// 앞왼쪽 다리 조인트.
    public let legFL = SCNNode()
    /// 앞오른쪽 다리 조인트.
    public let legFR = SCNNode()
    /// 뒤왼쪽 다리 조인트.
    public let legBL = SCNNode()
    /// 뒤오른쪽 다리 조인트.
    public let legBR = SCNNode()
    /// 꼬리 조인트 (tailColor nil이면 숨김).
    public let tail = SCNNode()
    /// 보행 위상 (walk(_:)가 누적).
    public var walkPhase: CGFloat = 0
    /// 몸통 기준 높이 (보행 bob 복원용).
    public var baseBodyY: CGFloat = 0.65

    /// 4족 릭을 만든다 (tailColor nil이면 꼬리 숨김).
    public init(bodyColor: VoxelColor, headColor: VoxelColor, legColor: VoxelColor, tailColor: VoxelColor? = nil) {
        super.init()
        let bodyMesh = vbox(0.5, 0.5, 0.85, bodyColor)
        body.addChildNode(bodyMesh)
        body.position = SCNVector3(0, baseBodyY, 0)
        addChildNode(body)
        head.position = SCNVector3(0, 0.20, 0.45)
        head.addChildNode(vbox(0.48, 0.48, 0.48, headColor))
        body.addChildNode(head)
        let legMeshes = (0..<4).map { _ in vbox(0.16, 0.45, 0.16, legColor) }
        let joints = [legFL, legFR, legBL, legBR]
        let spots = [SCNVector3(-0.18, -0.25, 0.25), SCNVector3(0.18, -0.25, 0.25),
                     SCNVector3(-0.18, -0.25, -0.28), SCNVector3(0.18, -0.25, -0.28)]
        for i in 0..<4 {
            joints[i].position = spots[i]
            legMeshes[i].position = SCNVector3(0, -0.225, 0)
            joints[i].addChildNode(legMeshes[i])
            body.addChildNode(joints[i])
        }
        tail.position = SCNVector3(0, 0.15, -0.42)
        if let tc = tailColor {
            let tm = vbox(0.12, 0.40, 0.12, tc)
            tm.position = SCNVector3(0, 0.16, -0.16)
            tail.addChildNode(tm)
            tail.isHidden = false
        } else {
            tail.isHidden = true
        }
        body.addChildNode(tail)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 보행 한 스텝: 다리 교대 회전 + 몸통 bob (t는 deltaTime).
    public func walk(_ t: TimeInterval) {
        walkPhase += CGFloat(t) * 11.0
        let cycle = sin(walkPhase)
        legFL.eulerAngles.x = cycle * 0.45
        legBR.eulerAngles.x = cycle * 0.45
        legFR.eulerAngles.x = -cycle * 0.45
        legBL.eulerAngles.x = -cycle * 0.45
        body.position.y = baseBodyY + abs(cycle) * 0.04
    }

    /// 씬에 추가한다 (scale은 전체 축소/확대 배율).
    public func addTo(_ scene: SCNScene, scale: CGFloat = 1.0) {
        self.scale = SCNVector3(scale, scale, scale)
        scene.rootNode.addChildNode(self)
    }
}

// MARK: - 2족 릭 (스켈레톤/좀비형)

/// 2족 복셀 릭: 머리+몸통+팔2+다리2, walk(_:) 보행 + attack() 팔 휘두르기.
public final class BipedRig: SCNNode {
    /// 몸통 메쉬 노드.
    public let torso = SCNNode()
    /// 머리 노드.
    public let head = SCNNode()
    /// 왼쪽 팔 조인트.
    public let armL = SCNNode()
    /// 오른쪽 팔 조인트 (attack 주체).
    public let armR = SCNNode()
    /// 왼쪽 다리 조인트.
    public let legL = SCNNode()
    /// 오른쪽 다리 조인트.
    public let legR = SCNNode()
    /// 보행 위상 (walk(_:)가 누적).
    public var walkPhase: CGFloat = 0

    /// 2족 릭을 만든다 (어깨 y=0.35, 골반 y=-0.40 기준).
    public init(headColor: VoxelColor, torsoColor: VoxelColor, limbColor: VoxelColor) {
        super.init()
        torso.geometry = SCNBox(width: 0.36, height: 0.80, length: 0.22, chamferRadius: 0)
        torso.geometry?.materials = [voxelMaterial(torsoColor)]
        torso.position = SCNVector3(0, 1.20, 0)
        addChildNode(torso)
        head.geometry = SCNBox(width: 0.50, height: 0.50, length: 0.50, chamferRadius: 0)
        head.geometry?.materials = [voxelMaterial(headColor)]
        head.position = SCNVector3(0, 0.55, 0)
        torso.addChildNode(head)
        let armMeshes = [vbox(0.12, 0.75, 0.12, limbColor), vbox(0.12, 0.75, 0.12, limbColor)]
        armL.position = SCNVector3(-0.25, 0.35, 0)
        armR.position = SCNVector3(0.25, 0.35, 0)
        for (j, m) in [(armL, armMeshes[0]), (armR, armMeshes[1])] {
            m.position = SCNVector3(0, -0.32, 0)
            j.addChildNode(m)
            torso.addChildNode(j)
        }
        let legMeshes = [vbox(0.12, 0.80, 0.12, limbColor), vbox(0.12, 0.80, 0.12, limbColor)]
        legL.position = SCNVector3(-0.10, -0.40, 0)
        legR.position = SCNVector3(0.10, -0.40, 0)
        for (j, m) in [(legL, legMeshes[0]), (legR, legMeshes[1])] {
            m.position = SCNVector3(0, -0.38, 0)
            j.addChildNode(m)
            torso.addChildNode(j)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 보행 한 스텝: 다리 교대 + 팔 반대위상 스윙 (t는 deltaTime).
    public func walk(_ t: TimeInterval) {
        walkPhase += CGFloat(t) * 10.0
        let cycle = sin(walkPhase)
        legL.eulerAngles.x = cycle * 0.42
        legR.eulerAngles.x = -cycle * 0.42
        armL.eulerAngles.x = -cycle * 0.35
        armR.eulerAngles.x = cycle * 0.35
    }

    /// 오른팔을 앞으로 휘두른다 (0.12초 올림 + 0.15초 복원).
    public func attack() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.12
        armR.eulerAngles.x = -1.9
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.15
            self.armR.eulerAngles.x = 0
            SCNTransaction.commit()
        }
        SCNTransaction.commit()
    }

    /// 씬에 추가한다 (scale은 전체 축소/확대 배율).
    public func addTo(_ scene: SCNScene, scale: CGFloat = 1.0) {
        self.scale = SCNVector3(scale, scale, scale)
        scene.rootNode.addChildNode(self)
    }
}

// MARK: - 비행 릭 (앵무새/박쥐/가스트형)

/// 비행 복셀 릭: 몸통+날개2, flap(_:) 날개 펄럭임.
public final class FlyerRig: SCNNode {
    /// 몸통 메쉬 노드.
    public let body = SCNNode()
    /// 왼쪽 날개 조인트 (z축 회전).
    public let wingL = SCNNode()
    /// 오른쪽 날개 조인트 (z축 회전).
    public let wingR = SCNNode()
    /// 날갯짓 위상 (flap(_:)이 누적).
    public var flapPhase: CGFloat = 0

    /// 비행 릭을 만든다 (날개는 몸통 양옆, 안쪽 가장자리 피벗).
    public init(bodyColor: VoxelColor, wingColor: VoxelColor) {
        super.init()
        body.addChildNode(vbox(0.32, 0.45, 0.32, bodyColor))
        body.position = SCNVector3(0, 0.60, 0)
        addChildNode(body)
        let meshes = [vbox(0.06, 0.42, 0.24, wingColor), vbox(0.06, 0.42, 0.24, wingColor)]
        wingL.position = SCNVector3(-0.18, 0.10, 0)
        wingR.position = SCNVector3(0.18, 0.10, 0)
        meshes[0].position = SCNVector3(-0.12, 0, 0)
        meshes[1].position = SCNVector3(0.12, 0, 0)
        wingL.addChildNode(meshes[0])
        wingR.addChildNode(meshes[1])
        body.addChildNode(wingL)
        body.addChildNode(wingR)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 날갯짓 한 스텝: 양날개 대칭 펄럭임 (t는 deltaTime).
    public func flap(_ t: TimeInterval) {
        flapPhase += CGFloat(t) * 24.0
        let f = sin(flapPhase) * 0.6
        wingL.eulerAngles.z = f
        wingR.eulerAngles.z = -f
    }

    /// 씬에 추가한다 (scale은 전체 축소/확대 배율).
    public func addTo(_ scene: SCNScene, scale: CGFloat = 1.0) {
        self.scale = SCNVector3(scale, scale, scale)
        scene.rootNode.addChildNode(self)
    }
}

// MARK: - 큐브 릭 (슬라임/마그마큐브형)

/// 큐브 복셀 릭: 반투명 큐브+눈, squash(_:) 스쿼시 점프 변형.
public final class CubeRig: SCNNode {
    /// 반투명 큐브 몸통.
    public let cube = SCNNode()
    /// 왼쪽 눈 (전면 +Z).
    public let eyeL = SCNNode()
    /// 오른쪽 눈 (전면 +Z).
    public let eyeR = SCNNode()

    /// 큐브 릭을 만든다 (size는 한 변 길이, alpha는 투명도).
    public init(color: VoxelColor, size: CGFloat = 1.0, alpha: CGFloat = 0.75) {
        super.init()
        let box = SCNBox(width: size, height: size, length: size, chamferRadius: 0)
        let mat = voxelMaterial(color)
        if case .rgb(let r, let g, let b) = color {
            mat.diffuse.contents = NSColor(red: r, green: g, blue: b, alpha: alpha)
            mat.transparency = alpha
        }
        box.materials = [mat]
        cube.geometry = box
        cube.position = SCNVector3(0, size / 2.0, 0)
        addChildNode(cube)
        let eyeBox = SCNBox(width: size * 0.12, height: size * 0.12, length: 0.02, chamferRadius: 0)
        let socket = SCNMaterial()
        socket.diffuse.contents = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        socket.lightingModel = .lambert
        eyeBox.materials = [socket]
        eyeL.geometry = eyeBox
        eyeR.geometry = eyeBox
        eyeL.position = SCNVector3(-size * 0.13, size * 0.08, size / 2.0 + 0.01)
        eyeR.position = SCNVector3(size * 0.13, size * 0.08, size / 2.0 + 0.01)
        cube.addChildNode(eyeL)
        cube.addChildNode(eyeR)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 스쿼시 변형: s=0 정상, s=1 최대 납작 (XZ 팽창 + Y 압축).
    public func squash(_ s: CGFloat) {
        let c = max(0, min(1, s))
        cube.scale = SCNVector3(1 + 0.25 * c, 1 - 0.25 * c, 1 + 0.25 * c)
    }

    /// 씬에 추가한다 (scale은 전체 축소/확대 배율).
    public func addTo(_ scene: SCNScene, scale: CGFloat = 1.0) {
        self.scale = SCNVector3(scale, scale, scale)
        scene.rootNode.addChildNode(self)
    }
}

// MARK: - 공용 SceneKit 뷰

/// 투명 배경 + 정면 고정 카메라의 60fps 몹 뷰 (클릭/드래그를 클로저로 전달).
public class MobSceneView: SCNView {
    /// 클릭(드래그 아닌 mouseUp) 시 호출된다.
    public var onTap: (() -> Void)?
    /// 드래그 중 화면 좌표가 전달된다.
    public var onDrag: ((CGPoint) -> Void)?
    /// 드래그 종료 시 throw 속도(pt/s, ±600 클램프)가 전달된다.
    public var onDragEnd: ((CGPoint) -> Void)?
    /// 현재 표시 중인 릭 (setSubject로 교체).
    public private(set) var subject: SCNNode?
    private var dragging = false
    private var lastPos: CGPoint = .zero
    private var lastTime: TimeInterval = 0
    private var velocity: CGPoint = .zero

    /// 투명 배경 + 조명 + 정면 카메라를 갖춘 뷰를 만든다.
    public override init(frame: NSRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        backgroundColor = .clear
        rendersContinuously = true
        preferredFramesPerSecond = 60
        antialiasingMode = .none
        let scene = SCNScene()
        self.scene = scene
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 36.0
        cam.position = SCNVector3(0, 1.0, 3.8)
        cam.eulerAngles = SCNVector3(-0.06, 0, 0)
        scene.rootNode.addChildNode(cam)
        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.color = NSColor(white: 0.70, alpha: 1.0)
        scene.rootNode.addChildNode(amb)
        let dir = SCNNode()
        dir.light = SCNLight()
        dir.light?.type = .directional
        dir.light?.color = NSColor(white: 0.75, alpha: 1.0)
        dir.position = SCNVector3(2, 5, 4)
        dir.eulerAngles = SCNVector3(-0.7, 0.4, 0)
        scene.rootNode.addChildNode(dir)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 표시할 릭을 교체한다 (기존 릭은 씬에서 제거).
    public func setSubject(_ node: SCNNode) {
        subject?.removeFromParentNode()
        subject = node
        node.position = SCNVector3(0, 0, 0)
        scene?.rootNode.addChildNode(node)
    }

    /// 드래그 시작점을 기록한다.
    public override func mouseDown(with event: NSEvent) {
        dragging = true
        lastPos = NSEvent.mouseLocation
        lastTime = ProcessInfo.processInfo.systemUptime
        velocity = .zero
    }

    /// 드래그 속도를 EMA로 누적하고 onDrag로 좌표를 전달한다.
    public override func mouseDragged(with event: NSEvent) {
        guard dragging else { return }
        let cur = NSEvent.mouseLocation
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastTime
        if dt > 0.001 {
            let vx = (cur.x - lastPos.x) / CGFloat(dt)
            let vy = (cur.y - lastPos.y) / CGFloat(dt)
            velocity = CGPoint(x: velocity.x * 0.4 + vx * 0.6, y: velocity.y * 0.4 + vy * 0.6)
        }
        lastPos = cur
        lastTime = now
        onDrag?(cur)
    }

    /// 정지 클릭이면 onTap, 이동이면 클램프된 속도로 onDragEnd를 호출한다.
    public override func mouseUp(with event: NSEvent) {
        guard dragging else { return }
        dragging = false
        if event.clickCount == 1 && hypot(velocity.x, velocity.y) < 50.0 {
            onTap?()
        } else {
            let m: CGFloat = 600.0
            onDragEnd?(CGPoint(x: max(-m, min(m, velocity.x)), y: max(-m, min(m, velocity.y))))
        }
    }
}
