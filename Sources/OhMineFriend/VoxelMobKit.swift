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
        m.lightingModel = .physicallyBased
        m.roughness.contents = 0.9
        m.metalness.contents = 0.0
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

// MARK: - 슬라임 릭 (반투명 겔 외피 + 불투명 코어)

/// 슬라임 복셀 릭: 반투명 겔 외피 + 불투명 내부 코어(눈·입) + 젤리 감쇠 진동.
///
/// 원작 슬라임은 **얼굴이 코어에만** 있고 외피에는 무늬만 있는 이중 구조다 — 외피 너머로
/// 코어가 비쳐 보이는 이 층이 젤리 깊이를 만든다(단일 반투명 큐브는 색 유리로 보인다).
/// 충격은 `bounce(_:)`로 넣고 `update(dt:)`가 매 프레임 변형을 적용하며, 변형 축은 발(y=0)이라
/// 바닥에 붙은 채 납작해진다.
public final class SlimeRig: SCNNode {
    /// 반투명 겔 외피 (한 변 = size).
    public let shell = SCNNode()
    /// 불투명 내부 코어 (한 변 = size * coreRatio, 전면 +Z에 눈·입).
    public let core = SCNNode()

    /// 외피 대비 코어 비율. 원작은 0.94(8 대 8.5)로 겔이 종이처럼 얇다 — 0.88로 조금 두껍게
    /// 잡아 겔 층이 읽히게 하고, 얼굴이 외피 밖으로 나오지 않는 여유(0.06)를 남긴다.
    private static let coreRatio: CGFloat = 0.88
    /// 감쇠 스프링 상수(진동 240 · 감쇠 7 → 감쇠비 ≈ 0.23, 서너 번 튕기고 잦아든다).
    private static let stiffness: CGFloat = 240.0
    private static let damping: CGFloat = 7.0

    // MARK: - 3/4 시점
    //
    // 정면 카메라로 정육면체를 똑바로 보면 세 면이 겹쳐 **정사각형 한 장(2D)** 으로 보인다
    // (팔다리가 있는 다른 몹은 앞뒤 부품이 어긋나 3D로 읽히지만 큐브에는 그 단서가 없다).
    // 그래서 슬라임만 몸을 35° 돌리고 카메라를 위에서 내려다보게 해 앞·옆·윗면 세 면이
    // 동시에 보이게 한다 — 윗면 능선(가까운 모서리가 가장 높은 6각 실루엣)이 3D 단서다.

    /// 몸을 트는 각(rad). 얼굴은 왼쪽 3/4로 남아 정면성이 유지된다.
    public static let viewYaw: CGFloat = 0.70
    /// 내려다보는 각(rad, 음수 = 아래로). 윗면이 보일 만큼만 기울인다.
    public static let viewPitch: CGFloat = -0.34

    /// 돌린 큐브의 가로 실루엣 배율(cos+sin) — 앞면 폭 예측 등에 쓴다.
    public static var widthFactor: CGFloat {
        cos(viewYaw) + sin(viewYaw)
    }

    /// 실루엣이 한 변보다 커지는 배율 — 세로 기준(내려보기로 윗면이 더해진다).
    public static var silhouetteFactor: CGFloat {
        cos(viewPitch) + sin(-viewPitch) * widthFactor
    }

    /// 채움 비율 `fill`에 맞춘 릭 배율과, 큐브 중심을 화면 중앙에 두는 카메라 높이.
    /// (돌리고 내려본 만큼 실루엣이 커지므로 그만큼 작게 잡는다.)
    public static func viewTransform(fill: CGFloat, edge: CGFloat) -> (scale: CGFloat, cameraY: CGFloat) {
        let worldEdge = fill * MobSceneView.visibleHeight / silhouetteFactor
        let scale = worldEdge / max(0.1, edge)
        let cameraY = worldEdge / 2.0 - sin(viewPitch) * MobSceneView.cameraZ
        return (scale, cameraY)
    }

    /// 변형 노드: 발(y=0)을 축으로 스쿼시·스트레치를 적용한다.
    private let deform = SCNNode()
    private var jiggle: CGFloat = 0        // + 납작 / − 늘어남
    private var jiggleVelocity: CGFloat = 0
    private var stretchAmount: CGFloat = 0
    private var flashTimer: TimeInterval = 0

    /// 코어는 외피보다 덜 변형된다 — 겔이 코어를 감싸고 있다는 인상을 주면서,
    /// 어떤 순간에도 코어가 외피 밖으로 삐져나오지 않는다(둘 다 중심을 공유한다).
    private static let coreDeformScale: CGFloat = 0.7

    private let shellMaterial: SCNMaterial
    private let coreMaterial: SCNMaterial
    private let eyeMaterial: SCNMaterial
    private let mouthMaterial: SCNMaterial

    /// 슬라임 릭을 만든다 (size는 복셀 한 변, 시드가 다르면 무늬가 달라진다).
    public init(size: CGFloat, shellSeed: UInt32 = 31, coreSeed: UInt32 = 32) {
        let edge = max(0.1, size)

        // 겔 외피: 원작 슬라임 팔레트(123,206,106 계열)에 투명도를 실어 반투명 재질로 만든다.
        let shellAlpha: CGFloat = 0.42
        shellMaterial = MobTexture.material(width: 8, height: 8, seed: shellSeed) { _, _, r in
            switch r {
            case ..<0.34: return NSColor(red: 0.451, green: 0.761, blue: 0.384, alpha: shellAlpha)
            case ..<0.67: return NSColor(red: 0.484, green: 0.808, blue: 0.418, alpha: shellAlpha)
            default: return NSColor(red: 0.384, green: 0.714, blue: 0.290, alpha: shellAlpha)
            }
        }
        shellMaterial.roughness.contents = 0.35      // 젖은 겔 하이라이트
        shellMaterial.writesToDepthBuffer = false    // 코어를 가리지 않고 그 위로 블렌딩만 한다
        shellMaterial.blendMode = .alpha

        // 내부 코어: 불투명하고 외피보다 한 톤 진한 무늬. 같은 시드를 쓰지 않아 무늬가 겹치지 않는다.
        let coreEdge = edge * Self.coreRatio
        coreMaterial = MobTexture.material(width: 8, height: 8, seed: coreSeed) { _, _, r in
            switch r {
            case ..<0.34: return NSColor(red: 0.353, green: 0.667, blue: 0.263, alpha: 1.0)
            case ..<0.67: return NSColor(red: 0.318, green: 0.627, blue: 0.243, alpha: 1.0)
            default: return NSColor(red: 0.286, green: 0.573, blue: 0.216, alpha: 1.0)
            }
        }
        coreMaterial.roughness.contents = 0.85

        // 얼굴(원작 배치): 눈은 8x8 얼굴 기준 2x2 두 개가 위쪽 1/4, 입은 아래쪽 가로 막대.
        eyeMaterial = MobTexture.material(width: 2, height: 2, seed: 1) { _, _, _ in
            NSColor(red: 0.039, green: 0.039, blue: 0.039, alpha: 1.0)
        }
        eyeMaterial.roughness.contents = 0.9
        mouthMaterial = MobTexture.material(width: 2, height: 2, seed: 2) { _, _, _ in
            NSColor(red: 0.086, green: 0.157, blue: 0.063, alpha: 1.0)
        }
        mouthMaterial.roughness.contents = 0.9

        super.init()

        let shellBox = SCNBox(width: edge, height: edge, length: edge, chamferRadius: 0)
        shellBox.materials = [shellMaterial]
        shell.geometry = shellBox
        shell.position = SCNVector3(0, edge / 2.0, 0)

        let coreBox = SCNBox(width: coreEdge, height: coreEdge, length: coreEdge, chamferRadius: 0)
        coreBox.materials = [coreMaterial]
        core.geometry = coreBox

        let faceDepth = coreEdge * 0.02
        // 코어 얼굴(겔 안쪽): 외피 너머로 비쳐 보이는 깊이를 만든다.
        addFace(to: core, extent: coreEdge, z: coreEdge / 2.0 + faceDepth / 2.0, depth: faceDepth)
        // 외피 얼굴(겔 표면): 원작처럼 겔 바깥면에도 같은 얼굴이 있어, 반투명 외피에 씻기지 않고
        // 또렷하게 보인다. 코어 얼굴이 그 뒤에 겹쳐 보여 얼굴이 겔 속에 잠긴 것처럼 읽힌다.
        addFace(to: shell, extent: coreEdge, z: edge / 2.0 + faceDepth / 2.0, depth: faceDepth)

        shell.addChildNode(core)
        deform.addChildNode(shell)
        deform.eulerAngles.y = Self.viewYaw
        addChildNode(deform)
    }

    /// 얼굴 노드(겔 표면 겹 + 코어 겹, 각 눈 2 + 입 1) — 연출·검증에서 참조한다.
    public private(set) var faceNodes: [SCNNode] = []

    /// 얼굴(눈 2개 + 입 1개)을 노드 앞면(+Z)에 붙인다. 비율은 원작 8x8 얼굴 기준
    /// (눈 2x2가 위쪽 1/4, 입은 아래쪽 가로 막대).
    private func addFace(to node: SCNNode, extent: CGFloat, z: CGFloat, depth: CGFloat) {
        let eyeBox = SCNBox(width: extent * 0.25, height: extent * 0.25, length: depth, chamferRadius: 0)
        eyeBox.materials = [eyeMaterial]
        for side in [-1.0, 1.0] as [CGFloat] {
            let eye = SCNNode(geometry: eyeBox)
            eye.position = SCNVector3(side * extent * 0.3125, extent * 0.125, z)
            node.addChildNode(eye)
            faceNodes.append(eye)
        }
        let mouthBox = SCNBox(width: extent * 0.75, height: extent * 0.125, length: depth, chamferRadius: 0)
        mouthBox.materials = [mouthMaterial]
        let mouth = SCNNode(geometry: mouthBox)
        mouth.position = SCNVector3(0, -extent * 0.3125, z)
        node.addChildNode(mouth)
        faceNodes.append(mouth)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 착지·피격 충격: 감쇠 진동을 되튀게 한다 (1.0 ≈ 10% 납작, 1.4 ≈ 15%).
    public func bounce(_ amount: CGFloat) {
        jiggleVelocity += amount * 10.0
    }

    /// 공중 체공 늘어남 (0 = 지면, 1 = 최대).
    public func stretch(_ amount: CGFloat) {
        stretchAmount = max(0, min(1, amount))
    }

    /// 피격 백색 섬광 (0.12초).
    public func flash() {
        flashTimer = 0.12
        setEmission(NSColor.white)
    }

    /// 스프링 감쇠와 섬광 복구를 진행하고 변형을 적용한다.
    public func update(dt: TimeInterval) {
        let step = CGFloat(min(max(dt, 0), 1.0 / 30.0))
        jiggleVelocity += (-Self.stiffness * jiggle - Self.damping * jiggleVelocity) * step
        jiggle = max(-0.6, min(0.6, jiggle + jiggleVelocity * step))

        if flashTimer > 0 {
            flashTimer -= dt
            if flashTimer <= 0 { setEmission(NSColor.black) }
        }

        let tall = 1 - 0.30 * jiggle + 0.14 * stretchAmount
        let wide = 1 + 0.22 * jiggle - 0.07 * stretchAmount
        deform.scale = SCNVector3(wide, tall, wide)
        // 충격에 몸이 살짝 비틀린다 (젤리 비틀림 — 진동과 함께 잦아든다)
        deform.eulerAngles.y = Self.viewYaw + jiggle * 0.12

        let k = Self.coreDeformScale
        core.scale = SCNVector3(1 + (wide - 1) * k, 1 + (tall - 1) * k, 1 + (wide - 1) * k)
    }

    private func setEmission(_ color: NSColor) {
        for material in [shellMaterial, coreMaterial, eyeMaterial, mouthMaterial] {
            material.emission.contents = color
        }
    }
}

// MARK: - 공용 SceneKit 뷰

/// 투명 배경 + 정면 고정 카메라의 60fps 몹 뷰 (클릭/드래그를 클로저로 전달).
public class MobSceneView: SCNView {
    /// 기본 정면 카메라 (모든 몹 뷰가 공유): 높이 1.0 · 거리 3.8 · 화각 36°.
    public static let cameraY: CGFloat = 1.0
    public static let cameraZ: CGFloat = 3.8
    public static let fov: CGFloat = 36.0
    public static let pitch: CGFloat = -0.06
    /// 이 카메라가 세로로 담는 월드 길이 (**중심 평면** 기준) — 3/4 시점 배율 계산에 쓴다.
    public static var visibleHeight: CGFloat {
        2.0 * cameraZ * tan(fov / 2.0 * .pi / 180.0)
    }

    /// 정면 고정 카메라를 조정한다 — 슬라임처럼 3/4 시점(위에서 내려다보기)이 필요한 뷰가 쓴다.
    public func setCamera(pitch: CGFloat, cameraY: CGFloat, cameraZ: CGFloat = MobSceneView.cameraZ) {
        guard let cameraNode = scene?.rootNode.childNode(withName: "stageCamera", recursively: false) else { return }
        cameraNode.position = SCNVector3(0, cameraY, cameraZ)
        cameraNode.eulerAngles = SCNVector3(pitch, 0, 0)
    }

    /// 클릭(드래그 아닌 mouseUp) 시 호출된다.
    public var onTap: (() -> Void)?
    /// 드래그 중 화면 좌표가 전달된다.
    public var onDrag: ((CGPoint) -> Void)?
    /// 드래그 종료 시 throw 속도(pt/s, ±600 클램프)가 전달된다.
    public var onDragEnd: ((CGPoint) -> Void)?
    /// 현재 표시 중인 릭 (setSubject로 교체).
    public private(set) var subject: SCNNode?
    /// setSubject가 릭을 붙이는 위치 (makeStage 반환).
    private var stageNode: SCNNode!
    private var dragging = false
    private var lastPos: CGPoint = .zero
    private var lastTime: TimeInterval = 0
    private var velocity: CGPoint = .zero

    /// 투명 배경 + 조명 + 정면 카메라를 갖춘 뷰를 만든다.
    public override init(frame: NSRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        let (scene, stage) = makeStage(
            cameraY: Self.cameraY,
            cameraZ: Self.cameraZ,
            fov: Self.fov,
            pitch: Self.pitch
        )
        self.scene = scene
        self.stageNode = stage
        configure(self)
        preferredFramesPerSecond = 60
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 표시할 릭을 교체한다 (기존 릭은 씬에서 제거).
    public func setSubject(_ node: SCNNode) {
        subject?.removeFromParentNode()
        subject = node
        node.position = SCNVector3(0, 0, 0)
        stageNode.addChildNode(node)
        if let scene = scene {
            StageBrightness.apply(to: scene)
        }
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
