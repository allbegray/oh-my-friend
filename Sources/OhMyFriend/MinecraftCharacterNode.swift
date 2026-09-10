import AppKit
import SceneKit

public enum HeldItem: String, CaseIterable {
    case none = "맨손 (None)"
    case diamondPickaxe = "다이아몬드 곡괭이 ⛏️"
    case diamondSword = "다이아몬드 검 🗡️"
    case goldenApple = "황금 사과 🍎"
    case torch = "레드스톤 횃불 🕯️"
}

public final class MinecraftCharacterNode: SCNNode {
    // Root container
    public let modelRoot = SCNNode()
    public let bodyAnchor = SCNNode()

    // Joints & Meshes
    public let torsoNode = SCNNode()
    public let headJoint = SCNNode()
    public let headMesh = SCNNode()

    public let rightArmJoint = SCNNode()
    public let rightArmMesh = SCNNode()

    public let leftArmJoint = SCNNode()
    public let leftArmMesh = SCNNode()

    // TNT block held in the right hand (during place & ignite)
    public let tntHandNode = SCNNode()

    public let rightLegJoint = SCNNode()
    public let rightLegMesh = SCNNode()

    public let leftLegJoint = SCNNode()
    public let leftLegMesh = SCNNode()

    // Hand Item Attachment Node
    public let rightHandItemAnchor = SCNNode()
    public var currentHeldItem: HeldItem = .none {
        didSet { updateHeldItemModel() }
    }

    // Interactive Placed Block Node (in front of player)
    public let placedBlockNode = SCNNode()

    // Floating Overhead Emoji Billboard
    public let overheadEmojiNode = SCNNode()
    private var emojiTimer: TimeInterval = 0

    // Current skin
    private var currentSkin: SkinTexture?

    // Look-at target euler angles
    public var targetHeadYaw: CGFloat = 0
    public var targetHeadPitch: CGFloat = 0
    private var currentHeadYaw: CGFloat = 0
    private var currentHeadPitch: CGFloat = 0

    // Animation progress timers
    private var animTime: CGFloat = 0
    public var walkSpeed: CGFloat = 0
    public var isSitting: Bool = false
    public var isFalling: Bool = false
    public var isPoking: Bool = false
    public var isHoldingTNT: Bool = false
    public var isPlacingTNT: Bool = false
    public var isBeingDragged: Bool = false

    // New Interactive Animations
    public var isWaving: Bool = false
    public var isSneaking: Bool = false
    public var isSleeping: Bool = false
    public var isBackflipping: Bool = false
    public var backflipAngle: CGFloat = 0
    public var isEating: Bool = false

    // Ladder climbing (사다리 등반)
    public var isClimbing: Bool = false {
        didSet {
            if oldValue && !isClimbing {
                // 사다리에서 내려오면 몸을 돌려 정면을 보고, 방향 플래그도 정리한다
                climbUp = false
                modelRoot.eulerAngles = SCNVector3(0, 0, 0)
            }
        }
    }
    public var climbProgress: CGFloat = 0
    /// 창문 위쪽으로 올라가는 중인지 (오르내리는 팔다리 위상 반전용)
    public var climbUp: Bool = false

    public override init() {
        super.init()
        setupHierarchy()
        setupPlacedBlock()
        setupEmojiBillboard()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupHierarchy() {
        addChildNode(modelRoot)
        modelRoot.addChildNode(bodyAnchor)

        // 1. Torso: W=0.8, H=1.2, L=0.4
        let torsoBox = SCNBox(width: 0.8, height: 1.2, length: 0.4, chamferRadius: 0)
        torsoNode.geometry = torsoBox
        torsoNode.position = SCNVector3(0, 1.8, 0)
        bodyAnchor.addChildNode(torsoNode)

        // 2. Head Joint (Pivot at neck: Y=2.4)
        headJoint.position = SCNVector3(0, 2.4, 0)
        let headBox = SCNBox(width: 0.8, height: 0.8, length: 0.8, chamferRadius: 0)
        headMesh.geometry = headBox
        headMesh.position = SCNVector3(0, 0.4, 0)
        headJoint.addChildNode(headMesh)
        bodyAnchor.addChildNode(headJoint)

        // 3. Right Arm Joint (Pivot at right shoulder: X = -0.6, Y = 2.4)
        rightArmJoint.position = SCNVector3(-0.6, 2.4, 0)
        let armBox = SCNBox(width: 0.4, height: 1.2, length: 0.4, chamferRadius: 0)
        rightArmMesh.geometry = armBox
        rightArmMesh.position = SCNVector3(0, -0.6, 0)
        rightArmJoint.addChildNode(rightArmMesh)
        bodyAnchor.addChildNode(rightArmJoint)

        // Mount item anchor at the bottom of right arm (hand position)
        rightHandItemAnchor.position = SCNVector3(0, -0.6, 0.2)
        rightArmMesh.addChildNode(rightHandItemAnchor)

        // 4. Left Arm Joint (Pivot at left shoulder: X = 0.6, Y = 2.4)
        leftArmJoint.position = SCNVector3(0.6, 2.4, 0)
        let leftArmBox = SCNBox(width: 0.4, height: 1.2, length: 0.4, chamferRadius: 0)
        leftArmMesh.geometry = leftArmBox
        leftArmMesh.position = SCNVector3(0, -0.6, 0)
        leftArmJoint.addChildNode(leftArmMesh)
        bodyAnchor.addChildNode(leftArmJoint)

        // 5. Right Leg Joint (Pivot at right hip: X = -0.2, Y = 1.2)
        rightLegJoint.position = SCNVector3(-0.2, 1.2, 0)
        let legBox = SCNBox(width: 0.4, height: 1.2, length: 0.4, chamferRadius: 0)
        rightLegMesh.geometry = legBox
        rightLegMesh.position = SCNVector3(0, -0.6, 0)
        rightLegJoint.addChildNode(rightLegMesh)
        bodyAnchor.addChildNode(rightLegJoint)

        // 6. Left Leg Joint (Pivot at left hip: X = 0.2, Y = 1.2)
        leftLegJoint.position = SCNVector3(0.2, 1.2, 0)
        let leftLegBox = SCNBox(width: 0.4, height: 1.2, length: 0.4, chamferRadius: 0)
        leftLegMesh.geometry = leftLegBox
        leftLegMesh.position = SCNVector3(0, -0.6, 0)
        leftLegJoint.addChildNode(leftLegMesh)
        bodyAnchor.addChildNode(leftLegJoint)

        // 7. TNT block (equipped in the right hand while placing)
        buildTNTHandItem()
        tntHandNode.position = SCNVector3(0, -0.95, 0) // just past the hand
        rightArmMesh.addChildNode(tntHandNode)
        tntHandNode.isHidden = true
    }

    private func buildTNTHandItem() {
        let red = SCNMaterial()
        red.diffuse.contents = NSColor(srgbRed: 0.80, green: 0.22, blue: 0.14, alpha: 1.0)
        let white = SCNMaterial()
        white.diffuse.contents = NSColor(white: 0.93, alpha: 1.0)

        let body = SCNNode()
        body.geometry = SCNBox(width: 0.5, height: 0.5, length: 0.5, chamferRadius: 0)
        body.geometry?.materials = [red]

        // TNT 텍스처의 하얀 밴드
        let band = SCNNode()
        band.geometry = SCNBox(width: 0.52, height: 0.16, length: 0.52, chamferRadius: 0)
        band.geometry?.materials = [white]
        band.position = SCNVector3(0, 0.02, 0)

        tntHandNode.addChildNode(body)
        tntHandNode.addChildNode(band)
    }

    private func setupPlacedBlock() {
        // Mini voxel block that appears when mining or building
        let box = SCNBox(width: 0.8, height: 0.8, length: 0.8, chamferRadius: 0.02)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.45, green: 0.28, blue: 0.15, alpha: 1.0) // dirt
        mat.lightingModel = .lambert
        box.materials = [mat]

        placedBlockNode.geometry = box
        placedBlockNode.position = SCNVector3(0, 0.4, 0.9)
        placedBlockNode.isHidden = true
        modelRoot.addChildNode(placedBlockNode)
    }

    private func setupEmojiBillboard() {
        overheadEmojiNode.position = SCNVector3(0, 3.5, 0)
        overheadEmojiNode.isHidden = true
        overheadEmojiNode.constraints = [SCNBillboardConstraint()]
        bodyAnchor.addChildNode(overheadEmojiNode)
    }

    public func showOverheadEmoji(_ emoji: String, duration: TimeInterval = 2.0) {
        overheadEmojiNode.childNodes.forEach { $0.removeFromParentNode() }

        // Render emoji to text geometry
        let textGeom = SCNText(string: emoji, extrusionDepth: 0.05)
        textGeom.font = NSFont.systemFont(ofSize: 0.5)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor.white
        textGeom.materials = [mat]

        let tNode = SCNNode(geometry: textGeom)
        // Center the text
        let (minVec, maxVec) = textGeom.boundingBox
        let w = maxVec.x - minVec.x
        tNode.position = SCNVector3(-w / 2.0, 0, 0)

        overheadEmojiNode.addChildNode(tNode)
        overheadEmojiNode.isHidden = false
        overheadEmojiNode.opacity = 1.0
        overheadEmojiNode.position.y = 3.4

        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        overheadEmojiNode.position.y = 3.9
        overheadEmojiNode.opacity = 0.0
        SCNTransaction.commit()
    }

    // MARK: - Held Item 3D Models
    private func updateHeldItemModel() {
        rightHandItemAnchor.childNodes.forEach { $0.removeFromParentNode() }

        switch currentHeldItem {
        case .none:
            break

        case .diamondPickaxe:
            let pickaxe = createPickaxeModel()
            rightHandItemAnchor.addChildNode(pickaxe)

        case .diamondSword:
            let sword = createSwordModel()
            rightHandItemAnchor.addChildNode(sword)

        case .goldenApple:
            let apple = createAppleModel()
            rightHandItemAnchor.addChildNode(apple)

        case .torch:
            let torch = createTorchModel()
            rightHandItemAnchor.addChildNode(torch)
        }
    }

    private func createPickaxeModel() -> SCNNode {
        let root = SCNNode()
        root.eulerAngles = SCNVector3(CGFloat.pi / 2.0, 0, 0)

        // Handle (wood)
        let handleBox = SCNBox(width: 0.08, height: 1.0, length: 0.08, chamferRadius: 0)
        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(red: 0.52, green: 0.35, blue: 0.18, alpha: 1.0)
        handleBox.materials = [woodMat]
        let handleNode = SCNNode(geometry: handleBox)
        handleNode.position = SCNVector3(0, 0.4, 0)
        root.addChildNode(handleNode)

        // Head (Diamond cyan)
        let headBox = SCNBox(width: 0.6, height: 0.12, length: 0.1, chamferRadius: 0)
        let diaMat = SCNMaterial()
        diaMat.diffuse.contents = NSColor(red: 0.2, green: 0.85, blue: 0.85, alpha: 1.0)
        headBox.materials = [diaMat]
        let headNode = SCNNode(geometry: headBox)
        headNode.position = SCNVector3(0, 0.9, 0)
        root.addChildNode(headNode)

        return root
    }

    private func createSwordModel() -> SCNNode {
        let root = SCNNode()
        root.eulerAngles = SCNVector3(CGFloat.pi / 2.0, 0, 0)

        // Handle
        let hBox = SCNBox(width: 0.08, height: 0.3, length: 0.08, chamferRadius: 0)
        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(red: 0.4, green: 0.25, blue: 0.1, alpha: 1.0)
        hBox.materials = [woodMat]
        let hNode = SCNNode(geometry: hBox)
        hNode.position = SCNVector3(0, 0.1, 0)
        root.addChildNode(hNode)

        // Guard
        let gBox = SCNBox(width: 0.35, height: 0.08, length: 0.1, chamferRadius: 0)
        let gMat = SCNMaterial()
        gMat.diffuse.contents = NSColor(red: 0.3, green: 0.7, blue: 0.7, alpha: 1.0)
        gBox.materials = [gMat]
        let gNode = SCNNode(geometry: gBox)
        gNode.position = SCNVector3(0, 0.28, 0)
        root.addChildNode(gNode)

        // Blade (Diamond)
        let bBox = SCNBox(width: 0.16, height: 0.85, length: 0.06, chamferRadius: 0)
        let diaMat = SCNMaterial()
        diaMat.diffuse.contents = NSColor(red: 0.2, green: 0.88, blue: 0.88, alpha: 1.0)
        bBox.materials = [diaMat]
        let bNode = SCNNode(geometry: bBox)
        bNode.position = SCNVector3(0, 0.7, 0)
        root.addChildNode(bNode)

        return root
    }

    private func createAppleModel() -> SCNNode {
        let root = SCNNode()
        let aBox = SCNBox(width: 0.3, height: 0.3, length: 0.3, chamferRadius: 0.04)
        let goldMat = SCNMaterial()
        goldMat.diffuse.contents = NSColor(red: 0.95, green: 0.8, blue: 0.15, alpha: 1.0)
        aBox.materials = [goldMat]
        let aNode = SCNNode(geometry: aBox)
        root.addChildNode(aNode)
        return root
    }

    private func createTorchModel() -> SCNNode {
        let root = SCNNode()
        let stickBox = SCNBox(width: 0.08, height: 0.5, length: 0.08, chamferRadius: 0)
        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(red: 0.5, green: 0.3, blue: 0.1, alpha: 1.0)
        stickBox.materials = [woodMat]
        let sNode = SCNNode(geometry: stickBox)
        root.addChildNode(sNode)

        let flameBox = SCNBox(width: 0.1, height: 0.15, length: 0.1, chamferRadius: 0)
        let flameMat = SCNMaterial()
        flameMat.diffuse.contents = NSColor(red: 0.95, green: 0.2, blue: 0.1, alpha: 1.0)
        flameBox.materials = [flameMat]
        let fNode = SCNNode(geometry: flameBox)
        fNode.position = SCNVector3(0, 0.3, 0)
        root.addChildNode(fNode)

        return root
    }

    public func applySkin(_ skin: SkinTexture) {
        self.currentSkin = skin

        headMesh.geometry?.materials = skin.materials(for: .head)
        torsoNode.geometry?.materials = skin.materials(for: .torso)
        rightArmMesh.geometry?.materials = skin.materials(for: .rightArm)
        leftArmMesh.geometry?.materials = skin.materials(for: .leftArm)
        rightLegMesh.geometry?.materials = skin.materials(for: .rightLeg)
        leftLegMesh.geometry?.materials = skin.materials(for: .leftLeg)
    }

    // MARK: - Update per frame (called by renderer loop)
    public func update(deltaTime dt: CGFloat) {
        animTime += dt
        tntHandNode.isHidden = !(isHoldingTNT || isPlacingTNT)

        // 1. Smooth Head LookAt Interpolation
        if !isSleeping && !isBackflipping && !isClimbing {
            let lerpFactor: CGFloat = min(dt * 8.0, 1.0)
            currentHeadYaw += (targetHeadYaw - currentHeadYaw) * lerpFactor
            currentHeadPitch += (targetHeadPitch - currentHeadPitch) * lerpFactor
            headJoint.eulerAngles = SCNVector3(currentHeadPitch, currentHeadYaw, 0)
        } else {
            headJoint.eulerAngles = SCNVector3(0, 0, 0)
        }

        // 2. Pose & Animations Priority Check
        if isBeingDragged {
            // Dragged: Dangle and flail arms & legs helplessly
            let flailR = sin(animTime * 15.0) * 0.7
            let flailL = cos(animTime * 15.0) * 0.7
            rightArmJoint.eulerAngles = SCNVector3(flailR, 0, 0.4)
            leftArmJoint.eulerAngles = SCNVector3(flailL, 0, -0.4)
            rightLegJoint.eulerAngles = SCNVector3(-flailL, 0, 0.2)
            leftLegJoint.eulerAngles = SCNVector3(-flailR, 0, -0.2)
            bodyAnchor.position = SCNVector3(0, sin(animTime * 12.0) * 0.05, 0)
            modelRoot.eulerAngles = SCNVector3(0, modelRoot.eulerAngles.y, 0)
            return
        }

        if isBackflipping {
            // 360 degree backflip rotation in air
            modelRoot.eulerAngles.x = backflipAngle
            rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi, 0, 0.3)
            leftArmJoint.eulerAngles = SCNVector3(-CGFloat.pi, 0, -0.3)
            rightLegJoint.eulerAngles = SCNVector3(0.5, 0, 0)
            leftLegJoint.eulerAngles = SCNVector3(0.5, 0, 0)
            return
        } else {
            modelRoot.eulerAngles.x = 0
        }

        if isSleeping {
            // Lie flat on back with slow deep breathing
            modelRoot.eulerAngles = SCNVector3(-CGFloat.pi / 2.0, 0, 0)
            let sleepBreath = sin(animTime * 1.5) * 0.04
            bodyAnchor.position = SCNVector3(0, 0.2 + sleepBreath, 0.7)
            rightArmJoint.eulerAngles = SCNVector3(0.3, 0, 0.2)
            leftArmJoint.eulerAngles = SCNVector3(0.3, 0, -0.2)
            rightLegJoint.eulerAngles = SCNVector3(0, 0, 0.1)
            leftLegJoint.eulerAngles = SCNVector3(0, 0, -0.1)
            return
        }

        if isClimbing {
            // Climbing: 창문을 마주보고(등을 보이며) 양팔 교차로 위를 움켜쥐고 다리를 교차로 디디며 오르내린다
            let cycle = sin(animTime * 5.0) * (climbUp ? -1.0 : 1.0)
            modelRoot.eulerAngles = SCNVector3(0, CGFloat.pi, 0)
            bodyAnchor.position = SCNVector3(0, cycle * 0.06, 0)
            rightArmJoint.eulerAngles = SCNVector3(-2.35 + cycle * 0.45, 0, 0.12)
            leftArmJoint.eulerAngles = SCNVector3(-2.35 - cycle * 0.45, 0, -0.12)
            rightLegJoint.eulerAngles = SCNVector3(0.45 - cycle * 0.35, 0, 0)
            leftLegJoint.eulerAngles = SCNVector3(0.45 + cycle * 0.35, 0, 0)
            return
        }

        if isFalling {
            // Falling: arms high up, legs slightly back
            let jitter = sin(animTime * 20.0) * 0.15
            rightArmJoint.eulerAngles = SCNVector3(-2.6 + jitter, 0, 0.3)
            leftArmJoint.eulerAngles = SCNVector3(-2.6 - jitter, 0, -0.3)
            rightLegJoint.eulerAngles = SCNVector3(0.4 + jitter, 0, 0.1)
            leftLegJoint.eulerAngles = SCNVector3(0.4 - jitter, 0, -0.1)
            bodyAnchor.position = SCNVector3(0, 0, 0)
            return
        }

        if isSitting {
            // Sitting: Legs 90 degrees forward, dangling slightly
            let dangle = sin(animTime * 3.0) * 0.15
            rightLegJoint.eulerAngles = SCNVector3(-CGFloat.pi / 2.0 + dangle, 0, 0)
            leftLegJoint.eulerAngles = SCNVector3(-CGFloat.pi / 2.0 - dangle, 0, 0)

            // Body lowered down
            bodyAnchor.position = SCNVector3(0, -0.7, 0)

            if isWaving {
                // Wave right hand while sitting
                let wave = sin(animTime * 10.0) * 0.4
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi + 0.3, 0, wave)
                leftArmJoint.eulerAngles = SCNVector3(-0.3, 0, -0.1)
            } else if isEating {
                // Eating motion
                let eatChomp = sin(animTime * 12.0) * 0.2
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 1.8 + eatChomp, 0, -0.3)
                leftArmJoint.eulerAngles = SCNVector3(-0.3, 0, -0.1)
            } else if isPoking {
                let punch = sin(animTime * 12.0) * 0.6
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 3.0 + punch, 0, 0)
                leftArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 6.0, 0, 0)
            } else {
                rightArmJoint.eulerAngles = SCNVector3(-0.3, 0, 0.1)
                leftArmJoint.eulerAngles = SCNVector3(-0.3, 0, -0.1)
            }
            return
        }

        // Standing / Sneaking / Walking / Waving / Eating / Poke
        if isSneaking {
            // Minecraft Shift Twerk / Crouch
            bodyAnchor.position = SCNVector3(0, -0.35, 0)
            torsoNode.eulerAngles.x = 0.35
            headJoint.position = SCNVector3(0, 2.1, 0.2)
            rightLegJoint.eulerAngles = SCNVector3(0.2, 0, 0)
            leftLegJoint.eulerAngles = SCNVector3(0.2, 0, 0)
        } else {
            bodyAnchor.position = SCNVector3(0, 0, 0)
            torsoNode.eulerAngles.x = 0
            headJoint.position = SCNVector3(0, 2.4, 0)
        }

        if walkSpeed > 0.05 {
            // Walking: swing arms and legs in opposition
            let stride = sin(animTime * 9.0) * 0.7 * min(walkSpeed, 1.5)
            rightLegJoint.eulerAngles = SCNVector3(stride, 0, 0)
            leftLegJoint.eulerAngles = SCNVector3(-stride, 0, 0)

            if isWaving {
                let wave = sin(animTime * 12.0) * 0.4
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi + 0.4, 0, wave)
                leftArmJoint.eulerAngles = SCNVector3(stride, 0, 0)
            } else if isPoking {
                let punch = sin(animTime * 15.0) * 0.8
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 2.0 + punch, 0, 0)
                leftArmJoint.eulerAngles = SCNVector3(stride, 0, 0)
            } else {
                rightArmJoint.eulerAngles = SCNVector3(-stride, 0, 0)
                leftArmJoint.eulerAngles = SCNVector3(stride, 0, 0)
            }

            // Slight vertical bobbing while walking
            let bob = abs(sin(animTime * 9.0)) * 0.08
            bodyAnchor.position.y += bob
        } else {
            // Idle / Standing
            let breath = sin(animTime * 2.0) * 0.03
            bodyAnchor.position.y += breath

            if !isSneaking {
                rightLegJoint.eulerAngles = SCNVector3(0, 0, 0)
                leftLegJoint.eulerAngles = SCNVector3(0, 0, 0)
            }

            if isWaving {
                // Wave hand high up: arm pointing up and oscillating Z rotation
                let wave = sin(animTime * 10.0) * 0.45
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi + 0.3, 0, wave)
                leftArmJoint.eulerAngles = SCNVector3(0, 0, -0.05)
            } else if isEating {
                // Bring food to mouth and vibrate
                let chomp = sin(animTime * 14.0) * 0.15
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 1.7 + chomp, 0, -0.2)
                leftArmJoint.eulerAngles = SCNVector3(0, 0, -0.05)
            } else if isHoldingTNT {
                // TNT를 머리 위로 치켜들기 (점화 준비)
                let tremble = sin(animTime * 22.0) * 0.05
                rightArmJoint.eulerAngles = SCNVector3(-2.85 + tremble, 0, 0.12)
                leftArmJoint.eulerAngles = SCNVector3(-0.2, 0, -0.08)
            } else if isPlacingTNT {
                // 앉아서 발밑에 TNT를 내려놓기
                bodyAnchor.position.y = -0.35
                rightArmJoint.eulerAngles = SCNVector3(-0.55, 0, 0.1)
                leftArmJoint.eulerAngles = SCNVector3(0.15, 0, -0.05)
                rightLegJoint.eulerAngles = SCNVector3(0.25, 0, 0)
                leftLegJoint.eulerAngles = SCNVector3(0.25, 0, 0)
            } else if isPoking {
                // Minecraft punching animation: arm straight forward swinging up and down
                let punch = sin(animTime * 14.0) * 0.7
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 2.2 + punch, 0, -0.1)
                leftArmJoint.eulerAngles = SCNVector3(0, 0, -0.1)
            } else {
                rightArmJoint.eulerAngles = SCNVector3(breath * 2.0, 0, 0.05)
                leftArmJoint.eulerAngles = SCNVector3(breath * 2.0, 0, -0.05)
            }
        }
    }
}
