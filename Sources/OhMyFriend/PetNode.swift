import AppKit
import SceneKit
import CoreGraphics

public final class PetNode: SCNNode {
    public private(set) var kind: PetKind = .wolf

    // Joint Hierarchy
    public let modelRoot = SCNNode()
    public let bodyAnchor = SCNNode()
    public let headJoint = SCNNode()

    public let legFL = SCNNode() // Front Left
    public let legFR = SCNNode() // Front Right
    public let legBL = SCNNode() // Back Left
    public let legBR = SCNNode() // Back Right

    public let tailJoint = SCNNode()
    public let wingLeft = SCNNode()  // for parrot
    public let wingRight = SCNNode() // for parrot

    // Overhead Emoji Billboard
    public let overheadEmojiNode = SCNNode()

    // Animation States
    public var walkSpeed: CGFloat = 0
    public var isRunning: Bool = false
    public var isSitting: Bool = false
    public var wolfHealth: CGFloat = 1.0 // 0.0 ~ 1.0 (체력/호감도)
    public var isSleeping: Bool = false

    // Head LookAt
    public var targetHeadYaw: CGFloat = 0
    public var targetHeadPitch: CGFloat = 0
    private var currentHeadYaw: CGFloat = 0
    private var currentHeadPitch: CGFloat = 0

    private var animTime: CGFloat = 0

    public init(kind: PetKind = .wolf) {
        self.kind = kind
        super.init()
        setupHierarchy()
        setupModel()
        setupEmojiBillboard()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setKind(_ newKind: PetKind) {
        guard self.kind != newKind else { return }
        self.kind = newKind
        setupModel()
    }

    private func setupHierarchy() {
        addChildNode(modelRoot)
        modelRoot.addChildNode(bodyAnchor)

        bodyAnchor.addChildNode(headJoint)
        bodyAnchor.addChildNode(legFL)
        bodyAnchor.addChildNode(legFR)
        bodyAnchor.addChildNode(legBL)
        bodyAnchor.addChildNode(legBR)
        bodyAnchor.addChildNode(tailJoint)
        bodyAnchor.addChildNode(wingLeft)
        bodyAnchor.addChildNode(wingRight)
    }

    private func setupEmojiBillboard() {
        overheadEmojiNode.position = SCNVector3(0, 1.8, 0)
        overheadEmojiNode.isHidden = true
        overheadEmojiNode.constraints = [SCNBillboardConstraint()]
        bodyAnchor.addChildNode(overheadEmojiNode)
    }

    public func showOverheadEmoji(_ emoji: String, duration: TimeInterval = 1.8) {
        overheadEmojiNode.childNodes.forEach { $0.removeFromParentNode() }

        let textGeom = SCNText(string: emoji, extrusionDepth: 0.04)
        textGeom.font = NSFont.systemFont(ofSize: 0.38)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor.white
        textGeom.materials = [mat]

        let tNode = SCNNode(geometry: textGeom)
        let (minVec, maxVec) = textGeom.boundingBox
        let w = maxVec.x - minVec.x
        tNode.position = SCNVector3(-w / 2.0, 0, 0)

        overheadEmojiNode.addChildNode(tNode)
        overheadEmojiNode.isHidden = false
        overheadEmojiNode.opacity = 1.0
        overheadEmojiNode.position.y = 1.6

        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        overheadEmojiNode.position.y = 2.0
        overheadEmojiNode.opacity = 0.0
        SCNTransaction.commit()
    }


    public func feed() {
        self.wolfHealth = 1.0
        showOverheadEmoji("❤️❤️❤️", duration: 2.2)
        SoundAndEffectsManager.shared.play(.heart)
    }
    // MARK: - 3D Voxel Model Builders
    private func setupModel() {
        // Clear previous meshes
        let allJoints = [headJoint, bodyAnchor, legFL, legFR, legBL, legBR, tailJoint, wingLeft, wingRight]
        for joint in allJoints {
            joint.geometry = nil
            joint.childNodes.forEach { $0.removeFromParentNode() }
            joint.eulerAngles = SCNVector3Zero
            joint.position = SCNVector3Zero
            joint.isHidden = false
        }
        bodyAnchor.addChildNode(overheadEmojiNode) // re-attach emoji

        switch kind {
        case .wolf:
            buildWolfModel()
        case .cat:
            buildCatModel()
        case .parrot:
            buildParrotModel()
        case .pig:
            buildPigModel()
        case .horse:
            buildHorseModel()
        }
    }

    // 1. 🐺 마인크래프트 길들인 늑대/강아지 (Tamed Wolf)
    private func buildWolfModel() {
        let furMat = makeLambert(color: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0))
        let darkFurMat = makeLambert(color: NSColor(red: 0.72, green: 0.72, blue: 0.72, alpha: 1.0))
        let noseMat = makeLambert(color: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0))
        let collarMat = makeLambert(color: NSColor(red: 0.82, green: 0.12, blue: 0.12, alpha: 1.0)) // Red collar!

        // Body (Torso): W=0.5, H=0.5, L=0.85, at Y=0.65
        let bodyGeom = SCNBox(width: 0.50, height: 0.50, length: 0.85, chamferRadius: 0)
        bodyGeom.materials = [furMat]
        bodyAnchor.geometry = bodyGeom
        bodyAnchor.position = SCNVector3(0, 0.65, 0)

        // Mane / Neck Fur
        let maneGeom = SCNBox(width: 0.54, height: 0.54, length: 0.35, chamferRadius: 0)
        maneGeom.materials = [darkFurMat]
        let maneNode = SCNNode(geometry: maneGeom)
        maneNode.position = SCNVector3(0, 0, 0.28)
        bodyAnchor.addChildNode(maneNode)

        // Red Collar
        let collarGeom = SCNBox(width: 0.52, height: 0.12, length: 0.52, chamferRadius: 0)
        collarGeom.materials = [collarMat]
        let collarNode = SCNNode(geometry: collarGeom)
        collarNode.position = SCNVector3(0, 0.12, 0.44)
        bodyAnchor.addChildNode(collarNode)

        // Head Joint: Pivot at (0, 0.2, 0.45)
        headJoint.position = SCNVector3(0, 0.20, 0.45)
        let headGeom = SCNBox(width: 0.48, height: 0.48, length: 0.48, chamferRadius: 0)
        headGeom.materials = [furMat]
        let headMesh = SCNNode(geometry: headGeom)
        headMesh.position = SCNVector3(0, 0.18, 0.18)
        headJoint.addChildNode(headMesh)

        // Snout
        let snoutGeom = SCNBox(width: 0.24, height: 0.18, length: 0.26, chamferRadius: 0)
        snoutGeom.materials = [furMat]
        let snoutNode = SCNNode(geometry: snoutGeom)
        snoutNode.position = SCNVector3(0, -0.08, 0.25)
        headMesh.addChildNode(snoutNode)

        // Nose
        let noseGeom = SCNBox(width: 0.10, height: 0.08, length: 0.04, chamferRadius: 0)
        noseGeom.materials = [noseMat]
        let noseNode = SCNNode(geometry: noseGeom)
        noseNode.position = SCNVector3(0, 0.04, 0.14)
        snoutNode.addChildNode(noseNode)

        // Ears (Pointed)
        let earGeom = SCNBox(width: 0.12, height: 0.16, length: 0.08, chamferRadius: 0)
        earGeom.materials = [furMat]
        let earL = SCNNode(geometry: earGeom)
        earL.position = SCNVector3(-0.16, 0.28, -0.06)
        let earR = SCNNode(geometry: earGeom)
        earR.position = SCNVector3(0.16, 0.28, -0.06)
        headMesh.addChildNode(earL)
        headMesh.addChildNode(earR)

        // 4 Legs: W=0.16, H=0.45, L=0.16
        let legGeom = SCNBox(width: 0.16, height: 0.45, length: 0.16, chamferRadius: 0)
        legGeom.materials = [furMat]

        buildLeg(legFL, geom: legGeom, x: -0.18, y: -0.25, z: 0.25)
        buildLeg(legFR, geom: legGeom, x: 0.18, y: -0.25, z: 0.25)
        buildLeg(legBL, geom: legGeom, x: -0.18, y: -0.25, z: -0.28)
        buildLeg(legBR, geom: legGeom, x: 0.18, y: -0.25, z: -0.28)

        // Tail: W=0.12, H=0.40, L=0.12, angled up at 45 deg
        let tailGeom = SCNBox(width: 0.12, height: 0.40, length: 0.12, chamferRadius: 0)
        tailGeom.materials = [furMat]
        let tailMesh = SCNNode(geometry: tailGeom)
        tailMesh.position = SCNVector3(0, 0.16, -0.16)
        tailMesh.eulerAngles.x = CGFloat.pi / 4.0 // 45 deg up!
        tailJoint.position = SCNVector3(0, 0.15, -0.42)
        tailJoint.addChildNode(tailMesh)

        wingLeft.isHidden = true
        wingRight.isHidden = true
    }

    // 2. 🐱 턱시도 고양이 (Tuxedo Cat)
    private func buildCatModel() {
        let blackMat = makeLambert(color: NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0))
        let whiteMat = makeLambert(color: NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0))
        let eyeMat = makeLambert(color: NSColor(red: 0.2, green: 0.85, blue: 0.2, alpha: 1.0)) // Green eyes
        let collarMat = makeLambert(color: NSColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0))

        // Body: W=0.40, H=0.38, L=0.75, at Y=0.55
        let bodyGeom = SCNBox(width: 0.40, height: 0.38, length: 0.75, chamferRadius: 0)
        bodyGeom.materials = [blackMat]
        bodyAnchor.geometry = bodyGeom
        bodyAnchor.position = SCNVector3(0, 0.55, 0)

        // White chest bib
        let chestGeom = SCNBox(width: 0.26, height: 0.24, length: 0.04, chamferRadius: 0)
        chestGeom.materials = [whiteMat]
        let chestNode = SCNNode(geometry: chestGeom)
        chestNode.position = SCNVector3(0, -0.05, 0.38)
        bodyAnchor.addChildNode(chestNode)

        // Red collar
        let collarGeom = SCNBox(width: 0.42, height: 0.08, length: 0.42, chamferRadius: 0)
        collarGeom.materials = [collarMat]
        let collarNode = SCNNode(geometry: collarGeom)
        collarNode.position = SCNVector3(0, 0.14, 0.38)
        bodyAnchor.addChildNode(collarNode)

        // Head: W=0.42, H=0.40, L=0.40
        headJoint.position = SCNVector3(0, 0.18, 0.42)
        let headGeom = SCNBox(width: 0.42, height: 0.40, length: 0.40, chamferRadius: 0)
        headGeom.materials = [blackMat]
        let headMesh = SCNNode(geometry: headGeom)
        headMesh.position = SCNVector3(0, 0.15, 0.15)
        headJoint.addChildNode(headMesh)

        // Snout (white)
        let snoutGeom = SCNBox(width: 0.20, height: 0.12, length: 0.12, chamferRadius: 0)
        snoutGeom.materials = [whiteMat]
        let snoutNode = SCNNode(geometry: snoutGeom)
        snoutNode.position = SCNVector3(0, -0.08, 0.22)
        headMesh.addChildNode(snoutNode)

        // Eyes (Green)
        let eyeGeom = SCNBox(width: 0.08, height: 0.08, length: 0.02, chamferRadius: 0)
        eyeGeom.materials = [eyeMat]
        let eyeL = SCNNode(geometry: eyeGeom)
        eyeL.position = SCNVector3(-0.10, 0.06, 0.21)
        let eyeR = SCNNode(geometry: eyeGeom)
        eyeR.position = SCNVector3(0.10, 0.06, 0.21)
        headMesh.addChildNode(eyeL)
        headMesh.addChildNode(eyeR)

        // Pointed Ears
        let earGeom = SCNBox(width: 0.10, height: 0.14, length: 0.06, chamferRadius: 0)
        earGeom.materials = [blackMat]
        let earL = SCNNode(geometry: earGeom)
        earL.position = SCNVector3(-0.14, 0.24, -0.04)
        let earR = SCNNode(geometry: earGeom)
        earR.position = SCNVector3(0.14, 0.24, -0.04)
        headMesh.addChildNode(earL)
        headMesh.addChildNode(earR)

        // 4 Legs: W=0.12, H=0.38, L=0.12 (black with white paws)
        let legGeom = SCNBox(width: 0.12, height: 0.38, length: 0.12, chamferRadius: 0)
        legGeom.materials = [blackMat]
        buildLeg(legFL, geom: legGeom, x: -0.14, y: -0.20, z: 0.24)
        buildLeg(legFR, geom: legGeom, x: 0.14, y: -0.20, z: 0.24)
        buildLeg(legBL, geom: legGeom, x: -0.14, y: -0.20, z: -0.24)
        buildLeg(legBR, geom: legGeom, x: 0.14, y: -0.20, z: -0.24)

        // Long swishing tail
        let tailGeom = SCNBox(width: 0.08, height: 0.55, length: 0.08, chamferRadius: 0)
        tailGeom.materials = [blackMat]
        let tailMesh = SCNNode(geometry: tailGeom)
        tailMesh.position = SCNVector3(0, 0.24, -0.20)
        tailMesh.eulerAngles.x = CGFloat.pi / 3.0
        tailJoint.position = SCNVector3(0, 0.10, -0.38)
        tailJoint.addChildNode(tailMesh)

        wingLeft.isHidden = true
        wingRight.isHidden = true
    }

    // 3. 🦜 붉은 앵무새 (Scarlet Parrot)
    private func buildParrotModel() {
        let redMat = makeLambert(color: NSColor(red: 0.90, green: 0.12, blue: 0.12, alpha: 1.0))
        let yellowMat = makeLambert(color: NSColor(red: 0.95, green: 0.85, blue: 0.10, alpha: 1.0))
        let blueMat = makeLambert(color: NSColor(red: 0.15, green: 0.40, blue: 0.90, alpha: 1.0))
        let clawMat = makeLambert(color: NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0))

        // Body: W=0.32, H=0.45, L=0.32, at Y=0.45
        let bodyGeom = SCNBox(width: 0.32, height: 0.45, length: 0.32, chamferRadius: 0)
        bodyGeom.materials = [redMat]
        bodyAnchor.geometry = bodyGeom
        bodyAnchor.position = SCNVector3(0, 0.45, 0)

        // Head: W=0.30, H=0.32, L=0.30
        headJoint.position = SCNVector3(0, 0.24, 0.08)
        let headGeom = SCNBox(width: 0.30, height: 0.32, length: 0.30, chamferRadius: 0)
        headGeom.materials = [redMat]
        let headMesh = SCNNode(geometry: headGeom)
        headMesh.position = SCNVector3(0, 0.14, 0.08)
        headJoint.addChildNode(headMesh)

        // Crest Feather on head
        let crestGeom = SCNBox(width: 0.06, height: 0.18, length: 0.10, chamferRadius: 0)
        crestGeom.materials = [redMat]
        let crestNode = SCNNode(geometry: crestGeom)
        crestNode.position = SCNVector3(0, 0.22, -0.04)
        crestNode.eulerAngles.x = -0.2
        headMesh.addChildNode(crestNode)

        // Beak (Yellow curved)
        let beakGeom = SCNBox(width: 0.10, height: 0.14, length: 0.14, chamferRadius: 0)
        beakGeom.materials = [yellowMat]
        let beakNode = SCNNode(geometry: beakGeom)
        beakNode.position = SCNVector3(0, -0.04, 0.18)
        headMesh.addChildNode(beakNode)

        // 2 Wings (Red with Yellow/Blue tips)
        let wingGeom = SCNBox(width: 0.06, height: 0.42, length: 0.24, chamferRadius: 0)
        wingGeom.materials = [blueMat]
        wingLeft.geometry = wingGeom
        wingLeft.position = SCNVector3(-0.18, 0, 0)
        wingRight.geometry = wingGeom
        wingRight.position = SCNVector3(0.18, 0, 0)

        // Long tail feathers
        let tailGeom = SCNBox(width: 0.14, height: 0.50, length: 0.04, chamferRadius: 0)
        tailGeom.materials = [blueMat]
        let tailMesh = SCNNode(geometry: tailGeom)
        tailMesh.position = SCNVector3(0, -0.22, -0.16)
        tailMesh.eulerAngles.x = 0.25
        tailJoint.position = SCNVector3(0, -0.10, -0.12)
        tailJoint.addChildNode(tailMesh)

        // 2 Claws: W=0.08, H=0.22, L=0.08
        let clawGeom = SCNBox(width: 0.08, height: 0.22, length: 0.08, chamferRadius: 0)
        clawGeom.materials = [clawMat]
        buildLeg(legFL, geom: clawGeom, x: -0.08, y: -0.25, z: 0.02)
        buildLeg(legFR, geom: clawGeom, x: 0.08, y: -0.25, z: 0.02)

        legBL.isHidden = true
        legBR.isHidden = true
    }

    // 4. 🐷 아기 돼지 (Pig)
    private func buildPigModel() {
        let pinkMat = makeLambert(color: NSColor(red: 0.95, green: 0.65, blue: 0.65, alpha: 1.0))
        let darkPinkMat = makeLambert(color: NSColor(red: 0.85, green: 0.52, blue: 0.52, alpha: 1.0))
        let eyeMat = makeLambert(color: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0))

        // Body: W=0.55, H=0.50, L=0.85, at Y=0.55
        let bodyGeom = SCNBox(width: 0.55, height: 0.50, length: 0.85, chamferRadius: 0)
        bodyGeom.materials = [pinkMat]
        bodyAnchor.geometry = bodyGeom
        bodyAnchor.position = SCNVector3(0, 0.55, 0)

        // Head: W=0.50, H=0.48, L=0.48
        headJoint.position = SCNVector3(0, 0.16, 0.44)
        let headGeom = SCNBox(width: 0.50, height: 0.48, length: 0.48, chamferRadius: 0)
        headGeom.materials = [pinkMat]
        let headMesh = SCNNode(geometry: headGeom)
        headMesh.position = SCNVector3(0, 0.15, 0.15)
        headJoint.addChildNode(headMesh)

        // Iconic Pig Snout
        let snoutGeom = SCNBox(width: 0.28, height: 0.18, length: 0.15, chamferRadius: 0)
        snoutGeom.materials = [darkPinkMat]
        let snoutNode = SCNNode(geometry: snoutGeom)
        snoutNode.position = SCNVector3(0, -0.06, 0.26)
        headMesh.addChildNode(snoutNode)

        // Eyes
        let eyeGeom = SCNBox(width: 0.08, height: 0.08, length: 0.02, chamferRadius: 0)
        eyeGeom.materials = [eyeMat]
        let eyeL = SCNNode(geometry: eyeGeom)
        eyeL.position = SCNVector3(-0.16, 0.08, 0.25)
        let eyeR = SCNNode(geometry: eyeGeom)
        eyeR.position = SCNVector3(0.16, 0.08, 0.25)
        headMesh.addChildNode(eyeL)
        headMesh.addChildNode(eyeR)

        // 4 Stumpy legs: W=0.18, H=0.32, L=0.18
        let legGeom = SCNBox(width: 0.18, height: 0.32, length: 0.18, chamferRadius: 0)
        legGeom.materials = [pinkMat]
        buildLeg(legFL, geom: legGeom, x: -0.16, y: -0.22, z: 0.24)
        buildLeg(legFR, geom: legGeom, x: 0.16, y: -0.22, z: 0.24)
        buildLeg(legBL, geom: legGeom, x: -0.16, y: -0.22, z: -0.24)
        buildLeg(legBR, geom: legGeom, x: 0.16, y: -0.22, z: -0.24)

        // Curly tail at back
        let tailGeom = SCNBox(width: 0.08, height: 0.12, length: 0.08, chamferRadius: 0)
        tailGeom.materials = [darkPinkMat]
        let tailMesh = SCNNode(geometry: tailGeom)
        tailMesh.position = SCNVector3(0, 0.08, -0.06)
        tailJoint.position = SCNVector3(0, 0.10, -0.44)
        tailJoint.addChildNode(tailMesh)

        wingLeft.isHidden = true
        wingRight.isHidden = true
    }

    private func buildHorseModel() {
        let coatMat = makeLambert(color: NSColor(red: 0.55, green: 0.36, blue: 0.20, alpha: 1.0))
        let maneMat = makeLambert(color: NSColor(red: 0.25, green: 0.15, blue: 0.08, alpha: 1.0))
        let saddleMat = makeLambert(color: NSColor(red: 0.70, green: 0.25, blue: 0.15, alpha: 1.0))
        let hoofMat = makeLambert(color: NSColor(red: 0.20, green: 0.18, blue: 0.16, alpha: 1.0))
        let eyeMat = makeLambert(color: NSColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0))

        let bodyGeom = SCNBox(width: 0.60, height: 0.65, length: 1.15, chamferRadius: 0)
        bodyGeom.materials = [coatMat]
        bodyAnchor.geometry = bodyGeom
        bodyAnchor.position = SCNVector3(0, 0.95, 0)

        let blanketGeom = SCNBox(width: 0.66, height: 0.14, length: 0.70, chamferRadius: 0)
        blanketGeom.materials = [saddleMat]
        let blanket = SCNNode(geometry: blanketGeom)
        blanket.position = SCNVector3(0, 0.34, -0.05)
        bodyAnchor.addChildNode(blanket)
        let seatGeom = SCNBox(width: 0.34, height: 0.12, length: 0.40, chamferRadius: 0)
        seatGeom.materials = [maneMat]
        let seat = SCNNode(geometry: seatGeom)
        seat.position = SCNVector3(0, 0.44, -0.05)
        bodyAnchor.addChildNode(seat)

        let neckGeom = SCNBox(width: 0.34, height: 0.62, length: 0.34, chamferRadius: 0)
        neckGeom.materials = [coatMat]
        let neck = SCNNode(geometry: neckGeom)
        neck.position = SCNVector3(0, 0.42, 0.62)
        neck.eulerAngles.x = -0.35
        bodyAnchor.addChildNode(neck)
        let maneGeom = SCNBox(width: 0.12, height: 0.60, length: 0.14, chamferRadius: 0)
        maneGeom.materials = [maneMat]
        let mane = SCNNode(geometry: maneGeom)
        mane.position = SCNVector3(0, 0.48, 0.44)
        mane.eulerAngles.x = -0.35
        bodyAnchor.addChildNode(mane)

        headJoint.position = SCNVector3(0, 0.62, 0.78)
        let headGeom = SCNBox(width: 0.36, height: 0.42, length: 0.55, chamferRadius: 0)
        headGeom.materials = [coatMat]
        let headMesh = SCNNode(geometry: headGeom)
        headMesh.position = SCNVector3(0, 0.18, 0.18)
        headJoint.addChildNode(headMesh)
        let eyeGeom = SCNBox(width: 0.07, height: 0.09, length: 0.02, chamferRadius: 0)
        eyeGeom.materials = [eyeMat]
        let eyeL = SCNNode(geometry: eyeGeom)
        eyeL.position = SCNVector3(-0.19, 0.08, 0.30)
        let eyeR = SCNNode(geometry: eyeGeom)
        eyeR.position = SCNVector3(0.19, 0.08, 0.30)
        headMesh.addChildNode(eyeL)
        headMesh.addChildNode(eyeR)
        let earGeom = SCNBox(width: 0.10, height: 0.18, length: 0.08, chamferRadius: 0)
        earGeom.materials = [coatMat]
        let earL = SCNNode(geometry: earGeom)
        earL.position = SCNVector3(-0.12, 0.30, 0.05)
        let earR = SCNNode(geometry: earGeom)
        earR.position = SCNVector3(0.12, 0.30, 0.05)
        headMesh.addChildNode(earL)
        headMesh.addChildNode(earR)

        let legGeom = SCNBox(width: 0.18, height: 0.70, length: 0.18, chamferRadius: 0)
        legGeom.materials = [coatMat]
        buildLeg(legFL, geom: legGeom, x: -0.20, y: -0.32, z: 0.40)
        buildLeg(legFR, geom: legGeom, x: 0.20, y: -0.32, z: 0.40)
        buildLeg(legBL, geom: legGeom, x: -0.20, y: -0.32, z: -0.40)
        buildLeg(legBR, geom: legGeom, x: 0.20, y: -0.32, z: -0.40)
        let hoofGeom = SCNBox(width: 0.20, height: 0.12, length: 0.20, chamferRadius: 0)
        hoofGeom.materials = [hoofMat]
        for leg in [legFL, legFR, legBL, legBR] {
            let hoof = SCNNode(geometry: hoofGeom)
            hoof.position = SCNVector3(0, -0.72, 0)
            leg.addChildNode(hoof)
        }

        let tailGeom = SCNBox(width: 0.14, height: 0.65, length: 0.14, chamferRadius: 0)
        tailGeom.materials = [maneMat]
        let tailMesh = SCNNode(geometry: tailGeom)
        tailMesh.position = SCNVector3(0, -0.25, -0.08)
        tailJoint.position = SCNVector3(0, 0.10, -0.58)
        tailJoint.addChildNode(tailMesh)

        wingLeft.isHidden = true
        wingRight.isHidden = true
    }

    private func buildLeg(_ legNode: SCNNode, geom: SCNBox, x: CGFloat, y: CGFloat, z: CGFloat) {
        legNode.position = SCNVector3(x, y, z)
        let mesh = SCNNode(geometry: geom)
        mesh.position = SCNVector3(0, -geom.height / 2.0, 0)
        legNode.addChildNode(mesh)
    }

    private func makeLambert(color: NSColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .lambert
        return mat
    }

    // MARK: - Animation Loop
    public func update(deltaTime dt: CGFloat) {
        animTime += dt

        // 1. Smooth Head LookAt
        let lerp: CGFloat = min(dt * 8.0, 1.0)
        currentHeadYaw += (targetHeadYaw - currentHeadYaw) * lerp
        currentHeadPitch += (targetHeadPitch - currentHeadPitch) * lerp
        headJoint.eulerAngles = SCNVector3(currentHeadPitch, currentHeadYaw, 0)

        // 2. Sleeping
        if isSleeping {
            bodyAnchor.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2.0)
            let sleepBreath = sin(animTime * 2.0) * 0.03
            bodyAnchor.position.y = 0.25 + sleepBreath
            legFL.eulerAngles = SCNVector3(0, 0, 0.3)
            legFR.eulerAngles = SCNVector3(0, 0, 0.3)
            legBL.eulerAngles = SCNVector3(0, 0, 0.3)
            legBR.eulerAngles = SCNVector3(0, 0, 0.3)
            return
        } else {
            bodyAnchor.eulerAngles = SCNVector3Zero
        }

        // 3. Sitting
        if isSitting {
            // Hind quarters drop down, front legs remain straight
            bodyAnchor.position.y = 0.40
            bodyAnchor.eulerAngles.x = -0.35
            legFL.eulerAngles = SCNVector3(0.35, 0, 0)
            legFR.eulerAngles = SCNVector3(0.35, 0, 0)
            legBL.eulerAngles = SCNVector3(1.1, 0, 0)
            legBR.eulerAngles = SCNVector3(1.1, 0, 0)

            // Tail wags gently when sitting
            let wag = sin(animTime * 6.0) * 0.3
            tailJoint.eulerAngles.y = wag

            // 원작 고증: 늑대 꼬리 각도는 체력에 비례
            if kind == .wolf {
                let basePitch = -0.45 + (wolfHealth * 1.15)
                tailJoint.eulerAngles.x = basePitch
            }
            return
        }

        // 4. Walking / Running
        let isMoving = abs(walkSpeed) > 10.0
        let speedMultiplier: CGFloat = isRunning ? 18.0 : 11.0
        let legSwingAmp: CGFloat = isRunning ? 0.65 : 0.45

        if isMoving {
            let cycle = sin(animTime * speedMultiplier)
            legFL.eulerAngles.x = cycle * legSwingAmp
            legBR.eulerAngles.x = cycle * legSwingAmp
            legFR.eulerAngles.x = -cycle * legSwingAmp
            legBL.eulerAngles.x = -cycle * legSwingAmp

            // Body slight bobbing
            let bob = abs(sin(animTime * speedMultiplier)) * 0.04
            bodyAnchor.position.y = (kind == .parrot ? 0.45 : (kind == .pig ? 0.55 : 0.65)) + bob

            // Tail wags vigorously when walking/running!
            let tailWagSpeed = isRunning ? 22.0 : 14.0
            tailJoint.eulerAngles.y = sin(animTime * tailWagSpeed) * 0.45

            // Parrot flaps wings when moving!
            if kind == .parrot {
                let flap = sin(animTime * 24.0) * 0.6
                wingLeft.eulerAngles.z = flap
                wingRight.eulerAngles.z = -flap
            }
        } else {
            legFL.eulerAngles.x = 0
            legFR.eulerAngles.x = 0
            legBL.eulerAngles.x = 0
            legBR.eulerAngles.x = 0

            // Idle tail wagging
            let idleWag = sin(animTime * 3.5) * 0.2
            tailJoint.eulerAngles.y = idleWag

            if kind == .wolf {
                let basePitch = -0.45 + (wolfHealth * 1.15)
                tailJoint.eulerAngles.x = basePitch
            }

            if kind == .parrot {
                wingLeft.eulerAngles.z = 0
                wingRight.eulerAngles.z = 0
            }
        }
    }
}
