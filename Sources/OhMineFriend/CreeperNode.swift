import AppKit
import SceneKit
import CoreGraphics

public enum CreeperLegType: String, CaseIterable {
    case quadruped = "quadruped" // 4족 크리퍼 (원작 고증)
    case biped = "biped"         // 2족 크리퍼 (직립 보행)

    public var displayName: String {
        switch self {
        case .quadruped: return "4족 크리퍼 (원작)"
        case .biped: return "2족 크리퍼 (직립)"
        }
    }
}

public final class CreeperNode: SCNNode {
    public let legType: CreeperLegType

    // Joint Hierarchy
    public let modelRoot = SCNNode()
    public let bodyAnchor = SCNNode()
    public let headNode = SCNNode()

    public let legFL = SCNNode() // Front Left (2족: Left Leg)
    public let legFR = SCNNode() // Front Right (2족: Right Leg)
    public let legBL = SCNNode() // Back Left
    public let legBR = SCNNode() // Back Right

    // Overhead Emoji
    public let overheadEmojiNode = SCNNode()

    // Animation Properties
    public var walkSpeed: CGFloat = 0
    public var fuseProgress: CGFloat = 0 // 0.0 ... 1.0 (swelling & flashing)
    public var isHissing: Bool = false
    public var isDying: Bool = false
    public var deathProgress: CGFloat = 0
    public var isHurt: Bool = false
    public var hurtTimer: TimeInterval = 0

    private var animTime: CGFloat = 0

    // Materials
    private let greenMat = SCNMaterial()
    private let darkGreenMat = SCNMaterial()
    private let blackMat = SCNMaterial()
    private let whiteFlashMat = SCNMaterial()
    private let redHurtMat = SCNMaterial()

    public init(legType: CreeperLegType = .quadruped) {
        self.legType = legType
        super.init()
        setupMaterials()
        setupHierarchy()
        setupModel()
        setupEmojiBillboard()
    }

    public override convenience init() {
        self.init(legType: .quadruped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupMaterials() {
        let greenCamo = MobTexture.material(width: 16, height: 16, seed: 7) { _, _, r in
            let base = NSColor(red: 0.28, green: 0.68, blue: 0.25, alpha: 1.0)
            if r < 0.15 { return MobTexture.shade(color: base, by: 0.55) }
            if r < 0.45 { return MobTexture.shade(color: base, by: 0.8) }
            return base
        }
        greenMat.diffuse.contents = greenCamo.diffuse.contents
        greenMat.diffuse.magnificationFilter = .nearest
        greenMat.diffuse.minificationFilter = .nearest
        greenMat.lightingModel = .physicallyBased
        greenMat.roughness.contents = 0.9
        greenMat.metalness.contents = 0.0

        let darkCamo = MobTexture.material(width: 16, height: 16, seed: 8) { _, _, r in
            let base = NSColor(red: 0.18, green: 0.48, blue: 0.16, alpha: 1.0)
            if r < 0.15 { return MobTexture.shade(color: base, by: 0.55) }
            if r < 0.45 { return MobTexture.shade(color: base, by: 0.8) }
            return base
        }
        darkGreenMat.diffuse.contents = darkCamo.diffuse.contents
        darkGreenMat.diffuse.magnificationFilter = .nearest
        darkGreenMat.diffuse.minificationFilter = .nearest
        darkGreenMat.lightingModel = .physicallyBased
        darkGreenMat.roughness.contents = 0.9
        darkGreenMat.metalness.contents = 0.0

        blackMat.diffuse.contents = NSColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        blackMat.lightingModel = .physicallyBased
        blackMat.roughness.contents = 0.85
        blackMat.metalness.contents = 0.0

        whiteFlashMat.diffuse.contents = NSColor.white
        whiteFlashMat.lightingModel = .constant

        redHurtMat.diffuse.contents = NSColor(red: 0.90, green: 0.20, blue: 0.20, alpha: 1.0)
        redHurtMat.lightingModel = .physicallyBased
        redHurtMat.roughness.contents = 0.85
        redHurtMat.metalness.contents = 0.0
    }

    private func setupHierarchy() {
        addChildNode(modelRoot)
        modelRoot.addChildNode(bodyAnchor)

        bodyAnchor.addChildNode(headNode)
        bodyAnchor.addChildNode(legFL)
        bodyAnchor.addChildNode(legFR)
        if legType == .quadruped {
            bodyAnchor.addChildNode(legBL)
            bodyAnchor.addChildNode(legBR)
        }
    }

    private func setupEmojiBillboard() {
        overheadEmojiNode.position = SCNVector3(0, 2.2, 0)
        overheadEmojiNode.isHidden = true
        overheadEmojiNode.constraints = [SCNBillboardConstraint()]
        bodyAnchor.addChildNode(overheadEmojiNode)
    }

    public func showOverheadEmoji(_ emoji: String, duration: TimeInterval = 1.8) {
        overheadEmojiNode.childNodes.forEach { $0.removeFromParentNode() }

        let bubble = EmojiBubble.node(for: emoji)
        overheadEmojiNode.addChildNode(bubble)
        overheadEmojiNode.isHidden = false
        overheadEmojiNode.opacity = 1.0
        overheadEmojiNode.position.y = 2.0

        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        overheadEmojiNode.position.y = 2.4
        overheadEmojiNode.opacity = 0.0
        SCNTransaction.commit()
    }

    // MARK: - 3D Voxel Creeper Builder
    private func setupModel() {
        // 1. Torso (Body): W=0.42, H=0.75, L=0.28 at Y=0.75
        let bodyBox = SCNBox(width: 0.42, height: 0.75, length: 0.28, chamferRadius: 0)
        bodyBox.materials = [greenMat]
        bodyAnchor.geometry = bodyBox
        bodyAnchor.position = SCNVector3(0, 0.75, 0)

        // Camo pattern patch on torso
        let camoPatch = SCNBox(width: 0.44, height: 0.35, length: 0.30, chamferRadius: 0)
        camoPatch.materials = [darkGreenMat]
        let patchNode = SCNNode(geometry: camoPatch)
        patchNode.position = SCNVector3(0, 0, 0)
        bodyAnchor.addChildNode(patchNode)

        // Mottled camo speckles (front + sides) for texture richness
        let speckSpots: [(CGFloat, CGFloat, CGFloat)] = [(-0.13, 0.28, 0.15), (0.14, 0.10, 0.15), (-0.05, -0.22, 0.15), (0.22, 0.28, 0.0), (-0.22, -0.05, 0.0)]
        for (sx, sy, sz) in speckSpots {
            let speckGeom = SCNBox(width: 0.09, height: 0.11, length: 0.02, chamferRadius: 0)
            speckGeom.materials = [darkGreenMat]
            let speck = SCNNode(geometry: speckGeom)
            speck.position = SCNVector3(sx, sy, sz)
            if sz == 0 {
                speck.eulerAngles.y = sx > 0 ? CGFloat.pi / 2.0 : -CGFloat.pi / 2.0
            }
            bodyAnchor.addChildNode(speck)
        }

        // 2. Head: W=0.55, H=0.55, L=0.55 at Y=0.65 relative to body
        let headBox = SCNBox(width: 0.55, height: 0.55, length: 0.55, chamferRadius: 0)
        headBox.materials = [greenMat]
        headNode.geometry = headBox
        headNode.position = SCNVector3(0, 0.65, 0)

        // Camo spots on head
        let headCamo = SCNBox(width: 0.56, height: 0.24, length: 0.56, chamferRadius: 0)
        headCamo.materials = [darkGreenMat]
        let hCamoNode = SCNNode(geometry: headCamo)
        hCamoNode.position = SCNVector3(0, 0.12, 0)
        headNode.addChildNode(hCamoNode)

        // Iconic Creeper Frowning Face on front (+Z):
        // Eyes (2 blocks, 0.12 x 0.12)
        let eyeBox = SCNBox(width: 0.12, height: 0.12, length: 0.02, chamferRadius: 0)
        eyeBox.materials = [blackMat]

        let eyeL = SCNNode(geometry: eyeBox)
        eyeL.position = SCNVector3(-0.13, 0.08, 0.28)
        let eyeR = SCNNode(geometry: eyeBox)
        eyeR.position = SCNVector3(0.13, 0.08, 0.28)
        headNode.addChildNode(eyeL)
        headNode.addChildNode(eyeR)

        // Center bridge between eyes & mouth
        let bridgeBox = SCNBox(width: 0.14, height: 0.14, length: 0.02, chamferRadius: 0)
        bridgeBox.materials = [blackMat]
        let bridgeNode = SCNNode(geometry: bridgeBox)
        bridgeNode.position = SCNVector3(0, -0.04, 0.28)
        headNode.addChildNode(bridgeNode)

        // Mouth top & center
        let mouthCenterBox = SCNBox(width: 0.14, height: 0.12, length: 0.02, chamferRadius: 0)
        mouthCenterBox.materials = [blackMat]
        let mouthCenter = SCNNode(geometry: mouthCenterBox)
        mouthCenter.position = SCNVector3(0, -0.15, 0.28)
        headNode.addChildNode(mouthCenter)

        // 2 Drooping Frown Corners (mouth corners extending downwards)
        let cornerBox = SCNBox(width: 0.08, height: 0.18, length: 0.02, chamferRadius: 0)
        cornerBox.materials = [blackMat]

        let cornerL = SCNNode(geometry: cornerBox)
        cornerL.position = SCNVector3(-0.11, -0.17, 0.28)
        let cornerR = SCNNode(geometry: cornerBox)
        cornerR.position = SCNVector3(0.11, -0.17, 0.28)
        headNode.addChildNode(cornerL)
        headNode.addChildNode(cornerR)

        // 3. Legs: 4 Stumpy Legs (quadruped) or 2 Sturdy Legs (biped)
        if legType == .quadruped {
            let legBox = SCNBox(width: 0.18, height: 0.38, length: 0.18, chamferRadius: 0)
            legBox.materials = [greenMat]

            buildLeg(legFL, geom: legBox, x: -0.12, y: -0.38, z: 0.14)
            buildLeg(legFR, geom: legBox, x: 0.12, y: -0.38, z: 0.14)
            buildLeg(legBL, geom: legBox, x: -0.12, y: -0.38, z: -0.14)
            buildLeg(legBR, geom: legBox, x: 0.12, y: -0.38, z: -0.14)
        } else {
            // 2족 직립 다리: 몸통 중심 Z=0 정렬, 안정적인 접지 폭 (L=0.22)
            let legBox = SCNBox(width: 0.18, height: 0.38, length: 0.22, chamferRadius: 0)
            legBox.materials = [greenMat]

            buildLeg(legFL, geom: legBox, x: -0.11, y: -0.38, z: 0.0)
            buildLeg(legFR, geom: legBox, x: 0.11, y: -0.38, z: 0.0)
        }
    }

    private func buildLeg(_ legNode: SCNNode, geom: SCNBox, x: CGFloat, y: CGFloat, z: CGFloat) {
        legNode.position = SCNVector3(x, y, z)
        let mesh = SCNNode(geometry: geom)
        mesh.position = SCNVector3(0, -geom.height / 2.0, 0)
        legNode.addChildNode(mesh)
    }

    // MARK: - Animation Loop
    public func update(deltaTime dt: CGFloat) {
        animTime += dt

        // 1. Hurt effect timer
        if hurtTimer > 0 {
            hurtTimer -= Double(dt)
            if hurtTimer <= 0 {
                isHurt = false
            }
        }

        // 2. Dying animation (tip over 90 degrees)
        if isDying {
            deathProgress = min(1.0, deathProgress + dt * 3.5)
            modelRoot.eulerAngles.z = deathProgress * (CGFloat.pi / 2.0)
            bodyAnchor.position.y = 0.75 - deathProgress * 0.45
            applyTint(color: redHurtMat)
            return
        }

        // 3. Hissing & Fuse Swelling / Flashing
        if isHissing {
            // Swell size up to 1.35x
            let swell = 1.0 + (fuseProgress * 0.35)
            modelRoot.scale = SCNVector3(swell, swell, swell)

            // Flash white rapidly
            let flash = sin(animTime * 26.0) > 0.1
            if flash {
                applyTint(color: whiteFlashMat)
            } else {
                restoreMaterials()
            }

            // Head twitching slightly
            headNode.eulerAngles.x = sin(animTime * 30.0) * 0.08
            headNode.eulerAngles.y = cos(animTime * 20.0) * 0.08
            return
        } else {
            modelRoot.scale = SCNVector3(1.0, 1.0, 1.0)
            if isHurt {
                applyTint(color: redHurtMat)
            } else {
                restoreMaterials()
            }
        }

        // 4. Creeper Walk Animation
        let isMoving = abs(walkSpeed) > 5.0
        if isMoving {
            let cycle = sin(animTime * 11.0)
            if legType == .quadruped {
                legFL.eulerAngles.x = cycle * 0.45
                legBR.eulerAngles.x = cycle * 0.45
                legFR.eulerAngles.x = -cycle * 0.45
                legBL.eulerAngles.x = -cycle * 0.45

                // Creepy subtle head bobbing
                headNode.eulerAngles.y = sin(animTime * 5.0) * 0.12
                headNode.eulerAngles.x = abs(cycle) * 0.06
                bodyAnchor.eulerAngles.z = 0
                bodyAnchor.eulerAngles.x = 0
            } else {
                // 2족 직립 보행: 좌우 다리 교대 스윙 및 상체 뒤뚱거림
                legFL.eulerAngles.x = cycle * 0.52
                legFR.eulerAngles.x = -cycle * 0.52

                // 유머러스한 2족 직립 뒤뚱거림(sway) 및 전진 기울기
                bodyAnchor.eulerAngles.z = sin(animTime * 5.5) * 0.05
                bodyAnchor.eulerAngles.x = 0.06

                headNode.eulerAngles.y = sin(animTime * 5.5) * 0.10
                headNode.eulerAngles.x = -0.04 + abs(cycle) * 0.04
            }
        } else {
            legFL.eulerAngles.x = 0
            legFR.eulerAngles.x = 0
            legBL.eulerAngles.x = 0
            legBR.eulerAngles.x = 0
            bodyAnchor.eulerAngles.z = 0
            bodyAnchor.eulerAngles.x = 0
            headNode.eulerAngles = SCNVector3Zero
        }
    }

    private func applyTint(color: SCNMaterial) {
        bodyAnchor.geometry?.materials = [color]
        headNode.geometry?.materials = [color]
    }

    private func restoreMaterials() {
        bodyAnchor.geometry?.materials = [greenMat]
        headNode.geometry?.materials = [greenMat]
    }
}
