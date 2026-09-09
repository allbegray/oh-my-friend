import AppKit
import SceneKit

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

    public let rightLegJoint = SCNNode()
    public let rightLegMesh = SCNNode()

    public let leftLegJoint = SCNNode()
    public let leftLegMesh = SCNNode()

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
    public var isBeingDragged: Bool = false

    public override init() {
        super.init()
        setupHierarchy()
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
        headMesh.position = SCNVector3(0, 0.4, 0) // center is 0.4 above neck
        headJoint.addChildNode(headMesh)
        bodyAnchor.addChildNode(headJoint)

        // 3. Right Arm Joint (Pivot at right shoulder: X = -0.6, Y = 2.4)
        rightArmJoint.position = SCNVector3(-0.6, 2.4, 0)
        let armBox = SCNBox(width: 0.4, height: 1.2, length: 0.4, chamferRadius: 0)
        rightArmMesh.geometry = armBox
        rightArmMesh.position = SCNVector3(0, -0.6, 0) // center is 0.6 below shoulder
        rightArmJoint.addChildNode(rightArmMesh)
        bodyAnchor.addChildNode(rightArmJoint)

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

        // 1. Smooth Head LookAt Interpolation
        let lerpFactor: CGFloat = min(dt * 8.0, 1.0)
        currentHeadYaw += (targetHeadYaw - currentHeadYaw) * lerpFactor
        currentHeadPitch += (targetHeadPitch - currentHeadPitch) * lerpFactor
        headJoint.eulerAngles = SCNVector3(currentHeadPitch, currentHeadYaw, 0)

        // 2. Pose & Animations
        if isBeingDragged {
            // Dragged: Dangle and flail arms & legs helplessly
            let flailR = sin(animTime * 15.0) * 0.7
            let flailL = cos(animTime * 15.0) * 0.7
            rightArmJoint.eulerAngles = SCNVector3(flailR, 0, 0.4)
            leftArmJoint.eulerAngles = SCNVector3(flailL, 0, -0.4)
            rightLegJoint.eulerAngles = SCNVector3(-flailL, 0, 0.2)
            leftLegJoint.eulerAngles = SCNVector3(-flailR, 0, -0.2)
            bodyAnchor.position = SCNVector3(0, sin(animTime * 12.0) * 0.05, 0)
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

            // Arms resting on knees or hanging
            if isPoking {
                let punch = sin(animTime * 12.0) * 0.6
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 3.0 + punch, 0, 0)
                leftArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 6.0, 0, 0)
            } else {
                rightArmJoint.eulerAngles = SCNVector3(-0.3, 0, 0.1)
                leftArmJoint.eulerAngles = SCNVector3(-0.3, 0, -0.1)
            }
            return
        }

        // Standing / Walking / Idle / Poke
        bodyAnchor.position = SCNVector3(0, 0, 0)

        if walkSpeed > 0.05 {
            // Walking: swing arms and legs in opposition
            let stride = sin(animTime * 9.0) * 0.7 * min(walkSpeed, 1.5)
            rightLegJoint.eulerAngles = SCNVector3(stride, 0, 0)
            leftLegJoint.eulerAngles = SCNVector3(-stride, 0, 0)

            if isPoking {
                let punch = sin(animTime * 15.0) * 0.8
                rightArmJoint.eulerAngles = SCNVector3(-CGFloat.pi / 2.0 + punch, 0, 0)
                leftArmJoint.eulerAngles = SCNVector3(stride, 0, 0)
            } else {
                rightArmJoint.eulerAngles = SCNVector3(-stride, 0, 0)
                leftArmJoint.eulerAngles = SCNVector3(stride, 0, 0)
            }

            // Slight vertical bobbing while walking
            let bob = abs(sin(animTime * 9.0)) * 0.08
            bodyAnchor.position = SCNVector3(0, bob, 0)
        } else {
            // Idle / Standing
            let breath = sin(animTime * 2.0) * 0.03
            bodyAnchor.position = SCNVector3(0, breath, 0)

            rightLegJoint.eulerAngles = SCNVector3(0, 0, 0)
            leftLegJoint.eulerAngles = SCNVector3(0, 0, 0)

            if isPoking {
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
