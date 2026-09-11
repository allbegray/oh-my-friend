import AppKit
import SceneKit

/// 전역 그래픽 스테이지 1단계: 조명·그림자·AA 중앙화.
///
/// Character/Pet/Creeper/Enderman/Skeleton/MobScene 6개 뷰가 복사 보유하던
/// 카메라+조명 설정을 여기로 모은다. 구도·밝기는 기존과 동일하게 유지하고
/// 은은한 그림자 + MSAA만 얹는다.
public enum StageQuality {
    case crisp
    case smooth
}

/// 절차적 스튜디오 환경맵 64x32 (파일·네트워크 없음).
public func makeStageEnvironmentImage() -> NSImage {
    let size = NSSize(width: 64, height: 32)
    let image = NSImage(size: size)
    image.lockFocus()
    if let gradient = NSGradient(colors: [NSColor(white: 1.0, alpha: 1.0),
                                          NSColor(white: 0.45, alpha: 1.0),
                                          NSColor(white: 0.12, alpha: 1.0)],
                                 atLocations: [0.0, 0.55, 1.0],
                                 colorSpace: .sRGB) {
        gradient.draw(in: NSRect(origin: .zero, size: size), angle: 90)
    } else {
        NSColor(white: 0.5, alpha: 1.0).setFill()
        NSRect(origin: .zero, size: size).fill()
    }
    NSColor(white: 1.0, alpha: 0.9).setFill()
    NSRect(x: 20, y: 20, width: 24, height: 8).fill()
    image.unlockFocus()
    return image
}

/// 전역 공유 스튜디오 환경 이미지 캐시
public let stageEnvironmentImage: NSImage = makeStageEnvironmentImage()

/// 투명 배경 scene + 정면 카메라 + 3점 조명 + 그림자 캐처를 만든다.
///
/// - Parameters:
///   - cameraY: 기존 각 뷰의 카메라 Y (그대로 전달)
///   - cameraZ: 기존 각 뷰의 카메라 Z (그대로 전달)
///   - fov: 기존 각 뷰의 fieldOfView (그대로 전달)
///   - pitch: 기존 각 뷰의 eulerAngles.x (그대로 전달)
/// - Returns: scene(뷰에 장착) + stage(캐릭터를 붙이는 위치, 발바닥 y=0).
public func makeStage(cameraY: CGFloat, cameraZ: CGFloat, fov: CGFloat = 36.0, pitch: CGFloat = -0.08) -> (scene: SCNScene, stage: SCNNode) {
    let scene = SCNScene()
    scene.background.contents = NSColor.clear

    // 정면 카메라 (수치는 호출 측 기존 값 그대로)
    let cameraNode = SCNNode()
    cameraNode.name = "stageCamera"
    let camera = SCNCamera()
    camera.fieldOfView = fov
    cameraNode.camera = camera
    cameraNode.position = SCNVector3(0, Float(cameraY), Float(cameraZ))
    cameraNode.eulerAngles = SCNVector3(Float(pitch), 0, 0)
    scene.rootNode.addChildNode(cameraNode)

    // 3점 조명
    let ambientNode = SCNNode()
    ambientNode.name = "stageAmbientLight"
    let ambient = SCNLight()
    ambient.type = .ambient
    ambientNode.light = ambient
    scene.rootNode.addChildNode(ambientNode)

    // 키 라이트: 우상단 전방 + 그림자
    let keyNode = SCNNode()
    keyNode.name = "stageKeyLight"
    let key = SCNLight()
    key.type = .directional
    key.shadowMode = .deferred
    key.shadowRadius = 8
    key.shadowColor = NSColor(white: 0, alpha: 0.35)
    key.shadowMapSize = CGSize(width: 2048, height: 2048)
    keyNode.light = key
    keyNode.position = SCNVector3(3, 7, 5)
    scene.rootNode.addChildNode(keyNode)
    keyNode.look(at: SCNVector3(0, 1, 0))

    // 림 라이트: 청백 후방 좌측
    let rimNode = SCNNode()
    rimNode.name = "stageRimLight"
    let rim = SCNLight()
    rim.type = .directional
    rimNode.light = rim
    rimNode.position = SCNVector3(-4, 3, -4)
    scene.rootNode.addChildNode(rimNode)
    rimNode.look(at: SCNVector3(0, 1, 0))

    // 그림자 캐처: y=0 평면, 그림자만 받고 색·깊이는 그리지 않는다
    let catcher = SCNNode()
    catcher.name = "stageShadowCatcher"
    let plane = SCNPlane(width: 30, height: 30)
    let mat = SCNMaterial()
    mat.lightingModel = .shadowOnly
    mat.transparency = 0.28
    mat.writesToDepthBuffer = false
    plane.firstMaterial = mat
    catcher.geometry = plane
    catcher.position = SCNVector3(0, 0, 0)
    catcher.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
    scene.rootNode.addChildNode(catcher)

    // 캐릭터를 붙이는 위치
    let stage = SCNNode()
    stage.name = "stageMount"
    stage.position = SCNVector3(0, 0, 0)
    scene.rootNode.addChildNode(stage)

    // 약참조 등록 및 현재 설정(광원 효과 on/off, 밝기) 즉시 반영
    StageBrightness.register(scene: scene)

    return (scene, stage)
}

/// SCNView 공용 설정: 지속 렌더 + 품질별 AA.
public func configure(_ view: SCNView, quality: StageQuality = .smooth) {
    view.backgroundColor = .clear
    view.rendersContinuously = true
    switch quality {
    case .smooth:
        view.antialiasingMode = .multisampling4X
    case .crisp:
        view.antialiasingMode = .none
    }
}
