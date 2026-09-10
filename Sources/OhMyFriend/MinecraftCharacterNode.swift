import AppKit
import SceneKit

public enum HeldItem: String, CaseIterable {
    case none = "맨손 (None)"
    case diamondPickaxe = "다이아몬드 곡괭이 ⛏️"
    case diamondSword = "다이아몬드 검 🗡️"
    case goldenApple = "황금 사과 🍎"
    case torch = "레드스톤 횃불 🕯️"
    case fishingRod = "낚싯대 🎣"
    case bone = "뼈다귀 🦴"
    case trident = "삼지창 🔱"
    case wheat = "밀 🌾"
    case milkBucket = "우유 양동이 🥛"
    case emptyBucket = "빈 양동이 🪣"
    case flower = "빨간 꽃 🌺"
    case balloon = "풍선 🎈"
    case shears = "가위 ✂️"
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

    // 2nd Layer (Overlays: Hat, Jacket, Sleeves, Pants)
    public let headOverlayMesh = SCNNode()
    public let torsoOverlayMesh = SCNNode()
    public let rightArmOverlayMesh = SCNNode()
    public let leftArmOverlayMesh = SCNNode()
    public let rightLegOverlayMesh = SCNNode()
    public let leftLegOverlayMesh = SCNNode()

    // Hand Item Attachment Node
    public let rightHandItemAnchor = SCNNode()
    public var currentHeldItem: HeldItem = .none {
        didSet { updateHeldItemModel() }
    }


    // Off-hand Shield (왼손 3D 방패)
    public let leftHandShieldAnchor = SCNNode()
    public var isShieldEquipped: Bool = false {
        didSet { updateShieldModel() }
    }
    public var isGuarding: Bool = false

    public let leftHandTotemAnchor = SCNNode()
    public var isTotemEquipped: Bool = false {
        didSet { updateTotemModel() }
    }

    // 🪽 겉날개 (Elytra)
    public let elytraNode = SCNNode()
    public let elytraWingLeft = SCNNode()
    public let elytraWingRight = SCNNode()
    public var isElytraEquipped: Bool = false {
        didSet { updateElytraModel() }
    }

    // 🔮 무기 인챈트 보라색 마법 광택 (Enchantment Glint)
    public var isEnchantedGlintEnabled: Bool = false {
        didSet {
            EnchantmentGlintShader.apply(to: rightHandItemAnchor, enabled: isEnchantedGlintEnabled)
            EnchantmentGlintShader.apply(to: leftHandShieldAnchor, enabled: isEnchantedGlintEnabled)
        }
    }
    public var isGliding: Bool = false
    // Interactive Placed Block Node (in front of player)
    public let placedBlockNode = SCNNode()

    // Interactive 3D Minecraft Red Bed (빨간 침대)
    public let bedNode = SCNNode()

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
    public var isCheering: Bool = false
    public var isNagging: Bool = false
    public var isAttackingWeapon: Bool = false
    public var isFishing: Bool = false
    public var isPressingDown: Bool = false
    public var isJukeboxDancing: Bool = false
    public var isThrowingTrident: Bool = false
    public var isReviving: Bool = false

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
        setupBed()
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

        // 1-Overlay. Torso Jacket: W=0.88, H=1.28, L=0.48
        let torsoOverlayBox = SCNBox(width: 0.88, height: 1.28, length: 0.48, chamferRadius: 0)
        torsoOverlayMesh.geometry = torsoOverlayBox
        // Elytra attached to back of torso
        elytraNode.position = SCNVector3(0, 0, -0.22)
        elytraNode.addChildNode(elytraWingLeft)
        elytraNode.addChildNode(elytraWingRight)
        torsoNode.addChildNode(elytraNode)
        torsoOverlayMesh.position = SCNVector3(0, 0, 0)
        torsoOverlayMesh.isHidden = true
        torsoNode.addChildNode(torsoOverlayMesh)

        // 2. Head Joint (Pivot at neck: Y=2.4)
        headJoint.position = SCNVector3(0, 2.4, 0)
        let headBox = SCNBox(width: 0.8, height: 0.8, length: 0.8, chamferRadius: 0)
        headMesh.geometry = headBox
        headMesh.position = SCNVector3(0, 0.4, 0)
        headJoint.addChildNode(headMesh)

        // 2-Overlay. Head Hat: W=0.88, H=0.88, L=0.88
        let headOverlayBox = SCNBox(width: 0.88, height: 0.88, length: 0.88, chamferRadius: 0)
        headOverlayMesh.geometry = headOverlayBox
        headOverlayMesh.position = SCNVector3(0, 0.4, 0)
        headOverlayMesh.isHidden = true
        headJoint.addChildNode(headOverlayMesh)
        bodyAnchor.addChildNode(headJoint)

        // 3. Right Arm Joint (Pivot at right shoulder: X = -0.6, Y = 2.4)
        rightArmJoint.position = SCNVector3(-0.6, 2.4, 0)
        let armBox = SCNBox(width: 0.4, height: 1.2, length: 0.4, chamferRadius: 0)
        rightArmMesh.geometry = armBox
        rightArmMesh.position = SCNVector3(0, -0.6, 0)
        rightArmJoint.addChildNode(rightArmMesh)

        // 3-Overlay. Right Arm Sleeve: W=0.48, H=1.28, L=0.48
        let rightArmOverlayBox = SCNBox(width: 0.48, height: 1.28, length: 0.48, chamferRadius: 0)
        rightArmOverlayMesh.geometry = rightArmOverlayBox
        rightArmOverlayMesh.position = SCNVector3(0, -0.6, 0)
        rightArmOverlayMesh.isHidden = true
        rightArmJoint.addChildNode(rightArmOverlayMesh)

        // Mount item anchor at the bottom of right arm (hand position)
        rightHandItemAnchor.position = SCNVector3(0, -0.6, 0.2)
        rightArmMesh.addChildNode(rightHandItemAnchor)
        bodyAnchor.addChildNode(rightArmJoint)

        // 4. Left Arm Joint (Pivot at left shoulder: X = 0.6, Y = 2.4)
        leftArmJoint.position = SCNVector3(0.6, 2.4, 0)
        let leftArmBox = SCNBox(width: 0.4, height: 1.2, length: 0.4, chamferRadius: 0)
        leftArmMesh.geometry = leftArmBox
        leftArmMesh.position = SCNVector3(0, -0.6, 0)
        leftArmJoint.addChildNode(leftArmMesh)

        // 4-Overlay. Left Arm Sleeve: W=0.48, H=1.28, L=0.48
        let leftArmOverlayBox = SCNBox(width: 0.48, height: 1.28, length: 0.48, chamferRadius: 0)
        leftArmOverlayMesh.geometry = leftArmOverlayBox
        leftArmOverlayMesh.position = SCNVector3(0, -0.6, 0)
        leftArmOverlayMesh.isHidden = true
        // Mount shield anchor on the left forearm
        leftHandShieldAnchor.position = SCNVector3(0, -0.45, 0.20)
        leftArmMesh.addChildNode(leftHandShieldAnchor)
        leftHandTotemAnchor.position = SCNVector3(0, -0.45, -0.20)
        leftArmMesh.addChildNode(leftHandTotemAnchor)
        leftArmJoint.addChildNode(leftArmOverlayMesh)
        bodyAnchor.addChildNode(leftArmJoint)

        // 5. Right Leg Joint (Pivot at right hip: X = -0.2, Y = 1.2)
        rightLegJoint.position = SCNVector3(-0.2, 1.2, 0)
        let legBox = SCNBox(width: 0.4, height: 1.2, length: 0.4, chamferRadius: 0)
        rightLegMesh.geometry = legBox
        rightLegMesh.position = SCNVector3(0, -0.6, 0)
        rightLegJoint.addChildNode(rightLegMesh)

        // 5-Overlay. Right Leg Pants: W=0.48, H=1.28, L=0.48
        let rightLegOverlayBox = SCNBox(width: 0.48, height: 1.28, length: 0.48, chamferRadius: 0)
        rightLegOverlayMesh.geometry = rightLegOverlayBox
        rightLegOverlayMesh.position = SCNVector3(0, -0.6, 0)
        rightLegOverlayMesh.isHidden = true
        rightLegJoint.addChildNode(rightLegOverlayMesh)
        bodyAnchor.addChildNode(rightLegJoint)

        // 6. Left Leg Joint (Pivot at left hip: X = 0.2, Y = 1.2)
        leftLegJoint.position = SCNVector3(0.2, 1.2, 0)
        let leftLegBox = SCNBox(width: 0.4, height: 1.2, length: 0.4, chamferRadius: 0)
        leftLegMesh.geometry = leftLegBox
        leftLegMesh.position = SCNVector3(0, -0.6, 0)
        leftLegJoint.addChildNode(leftLegMesh)

        // 6-Overlay. Left Leg Pants: W=0.48, H=1.28, L=0.48
        let leftLegOverlayBox = SCNBox(width: 0.48, height: 1.28, length: 0.48, chamferRadius: 0)
        leftLegOverlayMesh.geometry = leftLegOverlayBox
        leftLegOverlayMesh.position = SCNVector3(0, -0.6, 0)
        leftLegOverlayMesh.isHidden = true
        leftLegJoint.addChildNode(leftLegOverlayMesh)
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

    private func setupBed() {
        bedNode.childNodes.forEach { $0.removeFromParentNode() }

        // Authentic Minecraft Red Bed (마인크래프트 시그니처 빨간 침대)
        let woodDark = SCNMaterial()
        woodDark.diffuse.contents = NSColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0)
        let woodPlank = SCNMaterial()
        woodPlank.diffuse.contents = NSColor(red: 0.52, green: 0.35, blue: 0.18, alpha: 1.0)
        let whiteWool = SCNMaterial()
        whiteWool.diffuse.contents = NSColor(red: 0.94, green: 0.94, blue: 0.92, alpha: 1.0)
        let redWool = SCNMaterial()
        redWool.diffuse.contents = NSColor(red: 0.76, green: 0.14, blue: 0.14, alpha: 1.0)

        // 1. 4개의 원목 모서리 다리 (높이 0.2, 두께 0.18)
        let legW: CGFloat = 0.18
        let legH: CGFloat = 0.20
        let legGeom = SCNBox(width: legW, height: legH, length: legW, chamferRadius: 0)
        legGeom.materials = [woodDark]

        let halfX: CGFloat = 0.54
        let halfZ: CGFloat = 1.30
        let legOffsets: [(CGFloat, CGFloat)] = [
            (-halfX, -halfZ),
            (halfX, -halfZ),
            (-halfX, halfZ),
            (halfX, halfZ)
        ]
        for (ox, oz) in legOffsets {
            let leg = SCNNode(geometry: legGeom)
            leg.position = SCNVector3(ox, legH / 2.0, oz)
            bedNode.addChildNode(leg)
        }

        // 2. 침대 원목 프레임 바닥판 (width 1.32, height 0.14, length 2.85)
        let frameBase = SCNBox(width: 1.32, height: 0.14, length: 2.85, chamferRadius: 0)
        frameBase.materials = [woodPlank]
        let baseNode = SCNNode(geometry: frameBase)
        baseNode.position = SCNVector3(0, legH + 0.07, 0)
        bedNode.addChildNode(baseNode)

        // 3. 하얀색 베개 (width 1.20, height 0.16, length 0.75) - 머리 쪽(Z 음수 방향)
        let pillowGeom = SCNBox(width: 1.20, height: 0.16, length: 0.75, chamferRadius: 0.01)
        pillowGeom.materials = [whiteWool]
        let pillowNode = SCNNode(geometry: pillowGeom)
        pillowNode.position = SCNVector3(0, legH + 0.14 + 0.08, -0.95)
        bedNode.addChildNode(pillowNode)

        // 4. 하얀색 접힌 이불깃 스트라이프 (width 1.24, height 0.16, length 0.18)
        let stripeGeom = SCNBox(width: 1.24, height: 0.16, length: 0.18, chamferRadius: 0)
        stripeGeom.materials = [whiteWool]
        let stripeNode = SCNNode(geometry: stripeGeom)
        stripeNode.position = SCNVector3(0, legH + 0.14 + 0.08, -0.48)
        bedNode.addChildNode(stripeNode)

        // 5. 마인크래프트 레드 양모 이불/매트리스 (width 1.24, height 0.16, length 1.95)
        let blanketGeom = SCNBox(width: 1.24, height: 0.16, length: 1.95, chamferRadius: 0)
        blanketGeom.materials = [redWool]
        let blanketNode = SCNNode(geometry: blanketGeom)
        blanketNode.position = SCNVector3(0, legH + 0.14 + 0.08, 0.48)
        bedNode.addChildNode(blanketNode)

        bedNode.position = SCNVector3(0, 0, 0)
        bedNode.isHidden = true
        modelRoot.addChildNode(bedNode)
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
        let fontSize: CGFloat = emoji.count > 6 ? 0.34 : 0.50
        let textGeom = SCNText(string: emoji, extrusionDepth: 0.04)
        textGeom.font = NSFont.boldSystemFont(ofSize: fontSize)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor.white
        mat.lightingModel = .constant

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

        case .fishingRod:
            let rod = createFishingRodModel()
            rightHandItemAnchor.addChildNode(rod)

        case .bone:
            let bone = createBoneModel()
            rightHandItemAnchor.addChildNode(bone)

        case .trident:
            let trident = createTridentModel()
            rightHandItemAnchor.addChildNode(trident)

        case .wheat:
            let wheat = createWheatModel()
            rightHandItemAnchor.addChildNode(wheat)

        case .milkBucket:
            let milk = createBucketModel(fillColor: NSColor.white)
            rightHandItemAnchor.addChildNode(milk)

        case .emptyBucket:
            let empty = createBucketModel(fillColor: NSColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1.0))
            rightHandItemAnchor.addChildNode(empty)

        case .flower:
            let flower = createFlowerModel()
            rightHandItemAnchor.addChildNode(flower)

        case .balloon:
            let balloon = createBalloonModel()
            rightHandItemAnchor.addChildNode(balloon)

        case .shears:
            let shears = createShearsModel()
            rightHandItemAnchor.addChildNode(shears)
        }
        EnchantmentGlintShader.apply(to: rightHandItemAnchor, enabled: isEnchantedGlintEnabled)
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

    private func createFishingRodModel() -> SCNNode {
        let root = SCNNode()
        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(red: 0.52, green: 0.35, blue: 0.18, alpha: 1.0)
        let stringMat = SCNMaterial()
        stringMat.diffuse.contents = NSColor(white: 0.90, alpha: 0.85)
        let redMat = SCNMaterial()
        redMat.diffuse.contents = NSColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1.0)
        let whiteMat = SCNMaterial()
        whiteMat.diffuse.contents = NSColor.white

        // 1. 낚싯대 나무 대 (길이 1.45, 앞으로 비스듬히 뻗음)
        let poleBox = SCNBox(width: 0.06, height: 1.45, length: 0.06, chamferRadius: 0)
        poleBox.materials = [woodMat]
        let poleNode = SCNNode(geometry: poleBox)
        poleNode.position = SCNVector3(0, 0.60, 0.45)
        poleNode.eulerAngles.x = CGFloat.pi / 3.8
        root.addChildNode(poleNode)

        // 2. 낚싯줄 (끝에서 아래로 늘어뜨림)
        let lineBox = SCNBox(width: 0.02, height: 1.20, length: 0.02, chamferRadius: 0)
        lineBox.materials = [stringMat]
        let lineNode = SCNNode(geometry: lineBox)
        lineNode.position = SCNVector3(0, 0.65, 1.15)
        root.addChildNode(lineNode)

        // 3. 찌 (빨간색 & 하얀색 큐브)
        let bobberRed = SCNBox(width: 0.10, height: 0.06, length: 0.10, chamferRadius: 0)
        bobberRed.materials = [redMat]
        let bRed = SCNNode(geometry: bobberRed)
        bRed.position = SCNVector3(0, 0.08, 1.15)
        root.addChildNode(bRed)

        let bobberWhite = SCNBox(width: 0.10, height: 0.06, length: 0.10, chamferRadius: 0)
        bobberWhite.materials = [whiteMat]
        let bWhite = SCNNode(geometry: bobberWhite)
        bWhite.position = SCNVector3(0, 0.02, 1.15)
        root.addChildNode(bWhite)

        return root
    }

    private func createBoneModel() -> SCNNode {
        let root = SCNNode()
        let whiteMat = SCNMaterial()
        whiteMat.diffuse.contents = NSColor(red: 0.95, green: 0.95, blue: 0.92, alpha: 1.0)
        let mainShaft = SCNBox(width: 0.08, height: 0.65, length: 0.08, chamferRadius: 0.01)
        mainShaft.materials = [whiteMat]
        let sNode = SCNNode(geometry: mainShaft)
        sNode.position = SCNVector3(0, 0.35, 0)
        sNode.eulerAngles = SCNVector3(CGFloat.pi / 2.0, 0, 0)
        root.addChildNode(sNode)

        let knobGeom = SCNBox(width: 0.12, height: 0.10, length: 0.10, chamferRadius: 0)
        knobGeom.materials = [whiteMat]
        let k1 = SCNNode(geometry: knobGeom)
        k1.position = SCNVector3(0.06, 0.35, 0.30)
        let k2 = SCNNode(geometry: knobGeom)
        k2.position = SCNVector3(-0.06, 0.35, 0.30)
        let k3 = SCNNode(geometry: knobGeom)
        k3.position = SCNVector3(0.06, 0.35, -0.30)
        let k4 = SCNNode(geometry: knobGeom)
        k4.position = SCNVector3(-0.06, 0.35, -0.30)
        root.addChildNode(k1)
        root.addChildNode(k2)
        root.addChildNode(k3)
        root.addChildNode(k4)
        return root
    }

    /// 🔱 삼지창: 나무 손잡이 + 3갈래 다이아 촉 (H2 Trident)
    private func createTridentModel() -> SCNNode {
        let root = SCNNode()
        root.eulerAngles = SCNVector3(CGFloat.pi / 2.0, 0, 0)
        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(red: 0.45, green: 0.30, blue: 0.14, alpha: 1.0)
        let diaMat = SCNMaterial()
        diaMat.diffuse.contents = NSColor(red: 0.2, green: 0.85, blue: 0.85, alpha: 1.0)

        let shaftBox = SCNBox(width: 0.08, height: 1.1, length: 0.08, chamferRadius: 0)
        shaftBox.materials = [woodMat]
        let shaft = SCNNode(geometry: shaftBox)
        shaft.position = SCNVector3(0, 0.45, 0)
        root.addChildNode(shaft)

        let crossBox = SCNBox(width: 0.5, height: 0.08, length: 0.08, chamferRadius: 0)
        crossBox.materials = [diaMat]
        let cross = SCNNode(geometry: crossBox)
        cross.position = SCNVector3(0, 1.0, 0)
        root.addChildNode(cross)

        for x in [-0.21, 0.0, 0.21] as [CGFloat] {
            let prongBox = SCNBox(width: 0.07, height: 0.35, length: 0.07, chamferRadius: 0)
            prongBox.materials = [diaMat]
            let prong = SCNNode(geometry: prongBox)
            prong.position = SCNVector3(x, 1.2, 0)
            root.addChildNode(prong)
        }
        return root
    }

    /// 🌾 밀: 노란 줄기 + 이삭 (M4 Wheat)
    private func createWheatModel() -> SCNNode {
        let root = SCNNode()
        let stemMat = SCNMaterial()
        stemMat.diffuse.contents = NSColor(red: 0.55, green: 0.42, blue: 0.18, alpha: 1.0)
        let grainMat = SCNMaterial()
        grainMat.diffuse.contents = NSColor(red: 0.95, green: 0.82, blue: 0.30, alpha: 1.0)
        let stemBox = SCNBox(width: 0.06, height: 0.7, length: 0.06, chamferRadius: 0)
        stemBox.materials = [stemMat]
        let stem = SCNNode(geometry: stemBox)
        stem.position = SCNVector3(0, 0.3, 0)
        root.addChildNode(stem)
        for i in 0..<3 {
            let grainBox = SCNBox(width: 0.14, height: 0.12, length: 0.10, chamferRadius: 0)
            grainBox.materials = [grainMat]
            let grain = SCNNode(geometry: grainBox)
            grain.position = SCNVector3(0, 0.68 + CGFloat(i) * 0.13, 0)
            root.addChildNode(grain)
        }
        return root
    }

    private func createShearsModel() -> SCNNode {
        let root = SCNNode()
        let ironMat = SCNMaterial()
        ironMat.diffuse.contents = NSColor(red: 0.65, green: 0.66, blue: 0.68, alpha: 1.0)
        for x in [-0.06, 0.06] as [CGFloat] {
            let bladeBox = SCNBox(width: 0.05, height: 0.55, length: 0.05, chamferRadius: 0)
            bladeBox.materials = [ironMat]
            let blade = SCNNode(geometry: bladeBox)
            blade.position = SCNVector3(x, 0.35, 0)
            root.addChildNode(blade)
        }
        let pivotBox = SCNBox(width: 0.16, height: 0.08, length: 0.08, chamferRadius: 0)
        pivotBox.materials = [ironMat]
        let pivot = SCNNode(geometry: pivotBox)
        pivot.position = SCNVector3(0, 0.08, 0)
        root.addChildNode(pivot)
        return root
    }

    private func createBalloonModel() -> SCNNode {        let root = SCNNode()
        let stringMat = SCNMaterial()
        stringMat.diffuse.contents = NSColor(white: 0.9, alpha: 0.9)
        let balloonMat = SCNMaterial()
        balloonMat.diffuse.contents = NSColor(red: 0.95, green: 0.30, blue: 0.40, alpha: 1.0)
        let stringBox = SCNBox(width: 0.03, height: 0.6, length: 0.03, chamferRadius: 0)
        stringBox.materials = [stringMat]
        let string = SCNNode(geometry: stringBox)
        string.position = SCNVector3(0, 0.3, 0)
        root.addChildNode(string)
        let balloonBox = SCNBox(width: 0.42, height: 0.5, length: 0.42, chamferRadius: 0.12)
        balloonBox.materials = [balloonMat]
        let balloon = SCNNode(geometry: balloonBox)
        balloon.position = SCNVector3(0, 0.85, 0)
        root.addChildNode(balloon)
        return root
    }

    private func createFlowerModel() -> SCNNode {        let root = SCNNode()
        let stemMat = SCNMaterial()
        stemMat.diffuse.contents = NSColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        let petalMat = SCNMaterial()
        petalMat.diffuse.contents = NSColor(red: 0.9, green: 0.12, blue: 0.12, alpha: 1.0)
        let stemBox = SCNBox(width: 0.05, height: 0.5, length: 0.05, chamferRadius: 0)
        stemBox.materials = [stemMat]
        let stem = SCNNode(geometry: stemBox)
        stem.position = SCNVector3(0, 0.2, 0)
        root.addChildNode(stem)
        let headBox = SCNBox(width: 0.22, height: 0.22, length: 0.22, chamferRadius: 0.02)
        headBox.materials = [petalMat]
        let head = SCNNode(geometry: headBox)
        head.position = SCNVector3(0, 0.5, 0)
        root.addChildNode(head)
        return root
    }

    /// 🥛 양동이: 철 양동이 + 내용물 색상 (L2 Milk, 빈 양동이 겸용)
    private func createBucketModel(fillColor: NSColor) -> SCNNode {
        let root = SCNNode()
        let ironMat = SCNMaterial()
        ironMat.diffuse.contents = NSColor(red: 0.62, green: 0.63, blue: 0.66, alpha: 1.0)
        let fillMat = SCNMaterial()
        fillMat.diffuse.contents = fillColor
        let bodyBox = SCNBox(width: 0.3, height: 0.35, length: 0.3, chamferRadius: 0.02)
        bodyBox.materials = [ironMat]
        root.addChildNode(SCNNode(geometry: bodyBox))
        let fillBox = SCNBox(width: 0.26, height: 0.08, length: 0.26, chamferRadius: 0)
        fillBox.materials = [fillMat]
        let fill = SCNNode(geometry: fillBox)
        fill.position = SCNVector3(0, 0.16, 0)
        root.addChildNode(fill)
        return root
    }

    // MARK: - 3D Minecraft Shield Model
    private func updateShieldModel() {
        leftHandShieldAnchor.childNodes.forEach { $0.removeFromParentNode() }
        guard isShieldEquipped else { return }

        let ironMat = SCNMaterial()
        ironMat.diffuse.contents = NSColor(red: 0.60, green: 0.62, blue: 0.65, alpha: 1.0)
        ironMat.lightingModel = .lambert

        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(red: 0.82, green: 0.72, blue: 0.52, alpha: 1.0) // Birch wood
        woodMat.lightingModel = .lambert

        let darkIronMat = SCNMaterial()
        darkIronMat.diffuse.contents = NSColor(red: 0.40, green: 0.42, blue: 0.45, alpha: 1.0)
        darkIronMat.lightingModel = .lambert

        let root = SCNNode()
        // Iron outer rim: W=0.72, H=1.05, L=0.08
        let rimBox = SCNBox(width: 0.72, height: 1.05, length: 0.08, chamferRadius: 0.01)
        rimBox.materials = [ironMat]
        let rimNode = SCNNode(geometry: rimBox)
        root.addChildNode(rimNode)

        // Wood face: W=0.62, H=0.95, L=0.09
        let faceBox = SCNBox(width: 0.62, height: 0.95, length: 0.09, chamferRadius: 0)
        faceBox.materials = [woodMat]
        let faceNode = SCNNode(geometry: faceBox)
        root.addChildNode(faceNode)

        // Center metal stud: W=0.18, H=0.18, L=0.11
        let bossBox = SCNBox(width: 0.18, height: 0.18, length: 0.11, chamferRadius: 0)
        bossBox.materials = [darkIronMat]
        let bossNode = SCNNode(geometry: bossBox)
        root.addChildNode(bossNode)

        leftHandShieldAnchor.addChildNode(root)
        EnchantmentGlintShader.apply(to: leftHandShieldAnchor, enabled: isEnchantedGlintEnabled)
    }

    private func updateTotemModel() {
        leftHandTotemAnchor.childNodes.forEach { $0.removeFromParentNode() }
        guard isTotemEquipped else { return }
        let goldMat = SCNMaterial()
        goldMat.diffuse.contents = NSColor(red: 0.95, green: 0.75, blue: 0.20, alpha: 1.0)
        goldMat.lightingModel = .lambert
        let gemMat = SCNMaterial()
        gemMat.diffuse.contents = NSColor(red: 0.30, green: 0.85, blue: 0.95, alpha: 1.0)
        gemMat.lightingModel = .lambert
        let root = SCNNode()
        let bodyBox = SCNBox(width: 0.22, height: 0.55, length: 0.12, chamferRadius: 0.01)
        bodyBox.materials = [goldMat]
        root.addChildNode(SCNNode(geometry: bodyBox))
        let headBox = SCNBox(width: 0.18, height: 0.18, length: 0.12, chamferRadius: 0.01)
        headBox.materials = [goldMat]
        let head = SCNNode(geometry: headBox)
        head.position = SCNVector3(0, 0.36, 0)
        root.addChildNode(head)
        let gemBox = SCNBox(width: 0.10, height: 0.10, length: 0.13, chamferRadius: 0)
        gemBox.materials = [gemMat]
        let gem = SCNNode(geometry: gemBox)
        gem.position = SCNVector3(0, 0.05, 0)
        root.addChildNode(gem)
        leftHandTotemAnchor.addChildNode(root)
    }

    // MARK: - 3D Minecraft Elytra (겉날개)
    private func updateElytraModel() {
        elytraWingLeft.childNodes.forEach { $0.removeFromParentNode() }
        elytraWingRight.childNodes.forEach { $0.removeFromParentNode() }
        guard isElytraEquipped else { return }

        let wingMat = SCNMaterial()
        wingMat.diffuse.contents = NSColor(red: 0.22, green: 0.22, blue: 0.26, alpha: 1.0)
        wingMat.lightingModel = .lambert

        // Left wing: W=0.32, H=0.85, L=0.04
        let wingGeom = SCNBox(width: 0.32, height: 0.85, length: 0.04, chamferRadius: 0.01)
        wingGeom.materials = [wingMat]

        let meshL = SCNNode(geometry: wingGeom)
        meshL.position = SCNVector3(-0.16, -0.40, 0)
        elytraWingLeft.position = SCNVector3(-0.02, 0.40, 0)
        elytraWingLeft.addChildNode(meshL)

        // Right wing
        let meshR = SCNNode(geometry: wingGeom)
        meshR.position = SCNVector3(0.16, -0.40, 0)
        elytraWingRight.position = SCNVector3(0.02, 0.40, 0)
        elytraWingRight.addChildNode(meshR)
    }

    public func applySkin(_ skin: SkinTexture) {
        self.currentSkin = skin

        headMesh.geometry?.materials = skin.materials(for: .head)
        torsoNode.geometry?.materials = skin.materials(for: .torso)
        rightArmMesh.geometry?.materials = skin.materials(for: .rightArm)
        leftArmMesh.geometry?.materials = skin.materials(for: .leftArm)
        rightLegMesh.geometry?.materials = skin.materials(for: .rightLeg)
        leftLegMesh.geometry?.materials = skin.materials(for: .leftLeg)

        // 2nd Layer (Overlays: Hat, Jacket, Sleeves, Pants)
        applyOverlay(node: headOverlayMesh, materials: skin.overlayMaterials(for: .head))
        applyOverlay(node: torsoOverlayMesh, materials: skin.overlayMaterials(for: .torso))
        applyOverlay(node: rightArmOverlayMesh, materials: skin.overlayMaterials(for: .rightArm))
        applyOverlay(node: leftArmOverlayMesh, materials: skin.overlayMaterials(for: .leftArm))
        applyOverlay(node: rightLegOverlayMesh, materials: skin.overlayMaterials(for: .rightLeg))
        applyOverlay(node: leftLegOverlayMesh, materials: skin.overlayMaterials(for: .leftLeg))
    }

    private func applyOverlay(node: SCNNode, materials: [SCNMaterial]?) {
        if let materials = materials {
            node.geometry?.materials = materials
            node.isHidden = false
        } else {
            node.isHidden = true
        }
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
            bedNode.isHidden = false

            // 사용자가 침대와 누워있는 캐릭터를 한눈에 볼 수 있도록 입체 사각 시점으로 회전
            modelRoot.eulerAngles = SCNVector3(0.25, 0.60, 0)

            // 침대 매트리스 위에 캐릭터를 반듯하게 눕힘
            bodyAnchor.eulerAngles = SCNVector3(-CGFloat.pi / 2.0, 0, 0)

            let sleepBreath = sin(animTime * 1.8) * 0.035
            // 매트리스 위(Y=0.50)에 안착 및 호흡에 따른 가슴 오르내림
            bodyAnchor.position = SCNVector3(0, 0.50 + sleepBreath, 0.20)

            // 팔은 옆에 편안하게 내려놓음
            rightArmJoint.eulerAngles = SCNVector3(0.15, 0, 0.10)
            leftArmJoint.eulerAngles = SCNVector3(0.15, 0, -0.10)

            // 다리는 침대 위에 곧게 뻗음
            rightLegJoint.eulerAngles = SCNVector3(0, 0, 0.05)
            leftLegJoint.eulerAngles = SCNVector3(0, 0, -0.05)

            // 머리는 베개 위에 편안하게 얹고 미세하게 숨을 쉼
            headJoint.eulerAngles = SCNVector3(0.15, sin(animTime * 0.9) * 0.08, 0)
            return
        } else {
            bedNode.isHidden = true
            bodyAnchor.eulerAngles = SCNVector3(0, 0, 0)
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

        if isGliding {
            // 겉날개 활공 비행: 날개를 양옆으로 활짝 펴고 수평 활공 자세!
            elytraWingLeft.eulerAngles = SCNVector3(-0.25, 0.85, -0.45)
            elytraWingRight.eulerAngles = SCNVector3(-0.25, -0.85, 0.45)

            modelRoot.eulerAngles = SCNVector3(-CGFloat.pi / 2.3, 0, 0)
            bodyAnchor.position = SCNVector3(0, 0.25, 0)

            let flutter = sin(animTime * 15.0) * 0.05
            rightArmJoint.eulerAngles = SCNVector3(0.35 + flutter, 0, 0.15)
            leftArmJoint.eulerAngles = SCNVector3(0.35 + flutter, 0, -0.15)
            rightLegJoint.eulerAngles = SCNVector3(0.1, 0, 0.05)
            leftLegJoint.eulerAngles = SCNVector3(0.1, 0, -0.05)
            return
        } else {
            // 지상에서는 등 뒤로 얌전히 접힘
            elytraWingLeft.eulerAngles = SCNVector3(0.12, 0.15, -0.08)
            elytraWingRight.eulerAngles = SCNVector3(0.12, -0.15, 0.08)
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

            if isFishing {
                let bobJitter = sin(animTime * 5.0) * 0.04
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 3.2 + bobJitter, 0.2, 0.05)
                leftArmJoint.eulerAngles = SCNVector3(-0.2, 0, -0.1)
            } else
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

        if isJukeboxDancing {
            let sway = sin(animTime * 7.0) * 0.35
            headJoint.eulerAngles = SCNVector3(0, sway, sin(animTime * 3.5) * 0.1)
            let bob = abs(sin(animTime * 7.0)) * 0.12
            bodyAnchor.position = SCNVector3(sway * 0.2, bob, 0)
            rightArmJoint.eulerAngles = SCNVector3(-0.5 + sway * 0.4, 0, 0.35)
            leftArmJoint.eulerAngles = SCNVector3(-0.5 - sway * 0.4, 0, -0.35)
            return
        }

        if isThrowingTrident {
            let windup = sin(animTime * 9.0) * 0.5
            rightArmJoint.eulerAngles = SCNVector3(-2.4 + windup, 0, 0.2)
            leftArmJoint.eulerAngles = SCNVector3(-0.3, 0, -0.1)
            return
        }

        if isReviving {
            let glow = abs(sin(animTime * 10.0)) * 0.2
            bodyAnchor.position = SCNVector3(0, 0.25 + glow, 0)
            rightArmJoint.eulerAngles = SCNVector3(-2.8, 0, 0.4)
            leftArmJoint.eulerAngles = SCNVector3(-2.8, 0, -0.4)
            return
        }

        if isCheering {
            // Cheering / Fan dance: joyfully hopping up and down, waving both arms in the air!
            let hop = abs(sin(animTime * 14.0)) * 0.28
            bodyAnchor.position = SCNVector3(0, hop, 0)

            let armWave = sin(animTime * 14.0) * 0.4
            rightArmJoint.eulerAngles = SCNVector3(-2.6 + armWave, 0, 0.25)
            leftArmJoint.eulerAngles = SCNVector3(-2.6 - armWave, 0, -0.25)

            let legKick = sin(animTime * 14.0) * 0.2
            rightLegJoint.eulerAngles = SCNVector3(legKick, 0, 0)
            leftLegJoint.eulerAngles = SCNVector3(-legKick, 0, 0)
            return
        }

        if isNagging {
            // Nagging / Scolding motion:
            // 1. Head looks up towards the top-right notification corner
            headJoint.eulerAngles = SCNVector3(-0.35, 0.65, sin(animTime * 10.0) * 0.08)

            // 2. Right arm points aggressively towards the top-right corner with angry shaking
            let pointShake = sin(animTime * 18.0) * 0.12
            rightArmJoint.eulerAngles = SCNVector3(-2.2 + pointShake, 0.45, 0.35)

            // 3. Left hand on hip (scolding pose)
            leftArmJoint.eulerAngles = SCNVector3(0.5, 0, -0.65)

            // 4. Stomping feet angrily
            let stomp = abs(sin(animTime * 12.0)) * 0.18
            rightLegJoint.eulerAngles = SCNVector3(sin(animTime * 12.0) * 0.3, 0, 0)
            leftLegJoint.eulerAngles = SCNVector3(-sin(animTime * 12.0) * 0.1, 0, 0)
            bodyAnchor.position = SCNVector3(0, stomp, 0)
            return
        }

        if isPressingDown {
            // 창문을 짓눌러 압축하는 자세
            bodyAnchor.position = SCNVector3(0, -0.35, 0)
            let pressJitter = sin(animTime * 30.0) * 0.04
            rightArmJoint.eulerAngles = SCNVector3(0.75 + pressJitter, 0, 0.15)
            leftArmJoint.eulerAngles = SCNVector3(0.75 + pressJitter, 0, -0.15)
            rightLegJoint.eulerAngles = SCNVector3(0.2, 0, 0)
            leftLegJoint.eulerAngles = SCNVector3(0.2, 0, 0)
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
        let isActivelyGuarding = isShieldEquipped && (isSneaking || isGuarding)
        if isActivelyGuarding {
            // 방패를 가슴/얼굴 앞으로 번쩍 들어 올려 완벽 가드 자세!
            leftArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 2.2, 0.45, -0.65)
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
            } else if isAttackingWeapon {
                let slash = sin(animTime * 24.0) * 0.95
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 2.2 + slash, 0.25, -0.15)
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
            } else if isAttackingWeapon {
                let slash = sin(animTime * 24.0) * 0.95
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 2.2 + slash, 0.25, -0.15)
                leftArmJoint.eulerAngles = SCNVector3(0.2, 0, -0.2)
            } else {
                rightArmJoint.eulerAngles = SCNVector3(breath * 2.0, 0, 0.05)
                leftArmJoint.eulerAngles = SCNVector3(breath * 2.0, 0, -0.05)
            }
        }
    }
}
