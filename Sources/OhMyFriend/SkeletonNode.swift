import AppKit
import SceneKit
import CoreGraphics

public final class SkeletonNode: SCNNode {
    // Joint Hierarchy
    public let modelRoot = SCNNode()
    public let bodyAnchor = SCNNode()
    public let headNode = SCNNode()

    public let armLeftJoint = SCNNode()
    public let armRightJoint = SCNNode()
    public let legLeftJoint = SCNNode()
    public let legRightJoint = SCNNode()

    // 3D Wooden Bow
    public let bowNode = SCNNode()

    // Overhead Emoji
    public let overheadEmojiNode = SCNNode()

    // Flame nodes for daylight burning
    public let flameNode = SCNNode()

    // Animation Properties
    public var walkSpeed: CGFloat = 0
    public var isAiming: Bool = false
    public var isBurning: Bool = false
    public var isDying: Bool = false
    public var isHurt: Bool = false
    public var hurtTimer: TimeInterval = 0

    private var animTime: CGFloat = 0

    // Materials
    private let boneMat = SCNMaterial()
    private let darkBoneMat = SCNMaterial()
    private let socketMat = SCNMaterial()
    private let redHurtMat = SCNMaterial()
    private let flameMat = SCNMaterial()

    public override init() {
        super.init()
        setupMaterials()
        setupHierarchy()
        setupModel()
        setupBowModel()
        setupFlames()
        setupEmojiBillboard()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupMaterials() {
        boneMat.diffuse.contents = NSColor(red: 0.82, green: 0.82, blue: 0.80, alpha: 1.0)
        boneMat.lightingModel = .lambert

        darkBoneMat.diffuse.contents = NSColor(red: 0.65, green: 0.65, blue: 0.62, alpha: 1.0)
        darkBoneMat.lightingModel = .lambert

        socketMat.diffuse.contents = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        socketMat.lightingModel = .lambert

        redHurtMat.diffuse.contents = NSColor(red: 0.90, green: 0.18, blue: 0.18, alpha: 1.0)
        redHurtMat.lightingModel = .lambert

        flameMat.diffuse.contents = NSColor(red: 0.95, green: 0.40, blue: 0.10, alpha: 0.9)
        flameMat.lightingModel = .constant
    }

    private func setupHierarchy() {
        addChildNode(modelRoot)
        modelRoot.addChildNode(bodyAnchor)

        bodyAnchor.addChildNode(headNode)
        bodyAnchor.addChildNode(armLeftJoint)
        bodyAnchor.addChildNode(armRightJoint)
        bodyAnchor.addChildNode(legLeftJoint)
        bodyAnchor.addChildNode(legRightJoint)
        bodyAnchor.addChildNode(flameNode)

        armRightJoint.addChildNode(bowNode)
    }

    private func setupEmojiBillboard() {
        overheadEmojiNode.position = SCNVector3(0, 2.8, 0)
        overheadEmojiNode.isHidden = true
        overheadEmojiNode.constraints = [SCNBillboardConstraint()]
        bodyAnchor.addChildNode(overheadEmojiNode)
    }

    public func showOverheadEmoji(_ emoji: String, duration: TimeInterval = 1.8) {
        overheadEmojiNode.childNodes.forEach { $0.removeFromParentNode() }

        let bubble = EmojiBubble.node(for: emoji, worldHeight: emoji.count > 6 ? 0.4 : 0.55)
        overheadEmojiNode.addChildNode(bubble)
        overheadEmojiNode.isHidden = false
        overheadEmojiNode.opacity = 1.0
        overheadEmojiNode.position.y = 2.6

        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        overheadEmojiNode.position.y = 3.0
        overheadEmojiNode.opacity = 0.0
        SCNTransaction.commit()
    }

    // MARK: - 3D Skeleton Model Builder
    private func setupModel() {
        // 1. Ribcage / Torso: Slender bone column (W=0.36, H=0.80, L=0.22) at Y=1.20
        let ribBox = SCNBox(width: 0.36, height: 0.80, length: 0.22, chamferRadius: 0)
        ribBox.materials = [boneMat]
        bodyAnchor.geometry = ribBox
        bodyAnchor.position = SCNVector3(0, 1.20, 0)

        // Spine details (darker groove in middle)
        let spineBox = SCNBox(width: 0.14, height: 0.76, length: 0.24, chamferRadius: 0)
        spineBox.materials = [darkBoneMat]
        let sNode = SCNNode(geometry: spineBox)
        sNode.position = SCNVector3(0, 0, 0)
        bodyAnchor.addChildNode(sNode)

        // Rib bars (front): 4 horizontal ribs with dark gaps between
        for i in 0..<4 {
            let ribGeom = SCNBox(width: 0.40, height: 0.08, length: 0.04, chamferRadius: 0)
            ribGeom.materials = [boneMat]
            let rib = SCNNode(geometry: ribGeom)
            rib.position = SCNVector3(0, 0.26 - CGFloat(i) * 0.17, 0.12)
            bodyAnchor.addChildNode(rib)
        }

        // 2. Head (Skull): W=0.50, H=0.50, L=0.50 at Y=0.55 relative to body
        let skullBox = SCNBox(width: 0.50, height: 0.50, length: 0.50, chamferRadius: 0)
        skullBox.materials = [boneMat]
        headNode.geometry = skullBox
        headNode.position = SCNVector3(0, 0.55, 0)

        // Sunken hollow eye sockets (Front +Z)
        let eyeBox = SCNBox(width: 0.14, height: 0.13, length: 0.02, chamferRadius: 0)
        eyeBox.materials = [socketMat]
        let eyeL = SCNNode(geometry: eyeBox)
        eyeL.position = SCNVector3(-0.12, 0.05, 0.25)
        let eyeR = SCNNode(geometry: eyeBox)
        eyeR.position = SCNVector3(0.12, 0.05, 0.25)
        headNode.addChildNode(eyeL)
        headNode.addChildNode(eyeR)

        // Hollow nasal cavity
        let noseBox = SCNBox(width: 0.08, height: 0.08, length: 0.02, chamferRadius: 0)
        noseBox.materials = [socketMat]
        let noseNode = SCNNode(geometry: noseBox)
        noseNode.position = SCNVector3(0, -0.06, 0.25)
        headNode.addChildNode(noseNode)

        // Skull mouth / teeth slit
        let mouthBox = SCNBox(width: 0.26, height: 0.06, length: 0.02, chamferRadius: 0)
        mouthBox.materials = [socketMat]
        let mouthNode = SCNNode(geometry: mouthBox)
        mouthNode.position = SCNVector3(0, -0.16, 0.25)
        headNode.addChildNode(mouthNode)

        // Teeth: 3 bone teeth hanging over the mouth slit
        for i in -1...1 {
            let toothGeom = SCNBox(width: 0.05, height: 0.07, length: 0.02, chamferRadius: 0)
            toothGeom.materials = [boneMat]
            let tooth = SCNNode(geometry: toothGeom)
            tooth.position = SCNVector3(CGFloat(i) * 0.08, -0.15, 0.26)
            headNode.addChildNode(tooth)
        }

        // 3. Thin Bone Arms: W=0.12, H=0.75, L=0.12
        let armBox = SCNBox(width: 0.12, height: 0.75, length: 0.12, chamferRadius: 0)
        armBox.materials = [boneMat]

        armLeftJoint.position = SCNVector3(-0.25, 0.35, 0)
        let armLMesh = SCNNode(geometry: armBox)
        armLMesh.position = SCNVector3(0, -0.32, 0)
        armLeftJoint.addChildNode(armLMesh)

        armRightJoint.position = SCNVector3(0.25, 0.35, 0)
        let armRMesh = SCNNode(geometry: armBox)
        armRMesh.position = SCNVector3(0, -0.32, 0)
        armRightJoint.addChildNode(armRMesh)

        // 4. Thin Bone Legs: W=0.12, H=0.80, L=0.12
        let legBox = SCNBox(width: 0.12, height: 0.80, length: 0.12, chamferRadius: 0)
        legBox.materials = [boneMat]

        legLeftJoint.position = SCNVector3(-0.10, -0.40, 0)
        let legLMesh = SCNNode(geometry: legBox)
        legLMesh.position = SCNVector3(0, -0.38, 0)
        legLeftJoint.addChildNode(legLMesh)

        legRightJoint.position = SCNVector3(0.10, -0.40, 0)
        let legRMesh = SCNNode(geometry: legBox)
        legRMesh.position = SCNVector3(0, -0.38, 0)
        legRightJoint.addChildNode(legRMesh)
    }

    private func setupBowModel() {
        bowNode.childNodes.forEach { $0.removeFromParentNode() }

        let woodMat = SCNMaterial()
        woodMat.diffuse.contents = NSColor(red: 0.45, green: 0.28, blue: 0.14, alpha: 1.0)
        let stringMat = SCNMaterial()
        stringMat.diffuse.contents = NSColor(white: 0.95, alpha: 1.0)

        // Curved wooden bow frame (two angled limbs)
        let limbGeom = SCNBox(width: 0.06, height: 0.55, length: 0.06, chamferRadius: 0)
        limbGeom.materials = [woodMat]
        let limbTop = SCNNode(geometry: limbGeom)
        limbTop.position = SCNVector3(0, 0.22, 0.24)
        limbTop.eulerAngles.x = 0.45
        bowNode.addChildNode(limbTop)
        let limbBottom = SCNNode(geometry: limbGeom)
        limbBottom.position = SCNVector3(0, -0.22, 0.24)
        limbBottom.eulerAngles.x = -0.45
        bowNode.addChildNode(limbBottom)

        // Bowstring (drawn ahead of the limbs so it reads from the front)
        let stringGeom = SCNBox(width: 0.025, height: 1.0, length: 0.025, chamferRadius: 0)
        stringGeom.materials = [stringMat]
        let sNode = SCNNode(geometry: stringGeom)
        sNode.position = SCNVector3(0, 0, 0.30)
        bowNode.addChildNode(sNode)

        bowNode.position = SCNVector3(0, -0.35, 0.15)
    }

    private func setupFlames() {
        flameNode.childNodes.forEach { $0.removeFromParentNode() }
        flameNode.isHidden = true

        // Three dancing flame cubes around skeleton
        let f1 = SCNNode(geometry: SCNBox(width: 0.25, height: 0.35, length: 0.25, chamferRadius: 0))
        f1.geometry?.materials = [flameMat]
        f1.position = SCNVector3(0, 0.65, 0)
        let f2 = SCNNode(geometry: SCNBox(width: 0.20, height: 0.30, length: 0.20, chamferRadius: 0))
        f2.geometry?.materials = [flameMat]
        f2.position = SCNVector3(0.18, 0.15, 0.10)
        let f3 = SCNNode(geometry: SCNBox(width: 0.20, height: 0.30, length: 0.20, chamferRadius: 0))
        f3.geometry?.materials = [flameMat]
        f3.position = SCNVector3(-0.18, 0.15, -0.10)

        flameNode.addChildNode(f1)
        flameNode.addChildNode(f2)
        flameNode.addChildNode(f3)
    }

    // MARK: - Animation Loop
    public func update(deltaTime dt: CGFloat) {
        animTime += dt

        // 1. Hurt timer
        if hurtTimer > 0 {
            hurtTimer -= Double(dt)
            if hurtTimer <= 0 { isHurt = false }
        }

        // 2. Dying Animation (bone fracture collapse)
        if isDying {
            modelRoot.eulerAngles.z = min(CGFloat.pi / 2.0, modelRoot.eulerAngles.z + dt * 4.0)
            bodyAnchor.position.y = max(0.2, bodyAnchor.position.y - dt * 2.5)
            applyTint(color: redHurtMat)
            return
        }

        // 3. Daylight Burning
        flameNode.isHidden = !isBurning
        if isBurning {
            // Animate flames flickering
            let flameDance = sin(animTime * 22.0) * 0.08
            flameNode.position.y = flameDance
            // Shiver with fire damage
            let shiver = sin(animTime * 35.0) * 0.04
            modelRoot.position.x = shiver
        } else {
            modelRoot.position.x = 0
        }

        if isHurt {
            applyTint(color: redHurtMat)
        } else {
            restoreMaterials()
        }

        // 4. Aiming Bow Posture
        if isAiming {
            walkSpeed = 0
            // Right arm raises bow forward
            armRightJoint.eulerAngles = SCNVector3(-CGFloat.pi / 2.2, 0.35, 0)
            // Left arm reaches across to draw bowstring
            armLeftJoint.eulerAngles = SCNVector3(-CGFloat.pi / 2.4, -0.45, 0.2)
            headNode.eulerAngles.x = -0.1
            return
        }

        // 5. Walking Shuffle
        let isMoving = abs(walkSpeed) > 5.0
        if isMoving {
            let cycle = sin(animTime * 10.0)
            legLeftJoint.eulerAngles.x = cycle * 0.42
            legRightJoint.eulerAngles.x = -cycle * 0.42
            armLeftJoint.eulerAngles.x = -cycle * 0.35
            armRightJoint.eulerAngles.x = cycle * 0.35
        } else {
            legLeftJoint.eulerAngles.x = 0
            legRightJoint.eulerAngles.x = 0
            armLeftJoint.eulerAngles.x = 0
            armRightJoint.eulerAngles.x = 0
        }
    }

    private func applyTint(color: SCNMaterial) {
        bodyAnchor.geometry?.materials = [color]
        headNode.geometry?.materials = [color]
    }

    private func restoreMaterials() {
        bodyAnchor.geometry?.materials = [boneMat]
        headNode.geometry?.materials = [boneMat]
    }
}
