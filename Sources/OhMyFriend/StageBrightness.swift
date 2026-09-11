import AppKit
import Foundation
import SceneKit

/// 3D 스테이지 조명 및 밝기 공용 저장소 (프리셋 + 광원 효과 on/off + UserDefaults 영속).
public enum StageBrightness {
    /// 광원 효과 (3D 입체 광원, IBL 환경 반사, HDR 노출, 그림자, 림라이트) ON/OFF
    /// 기본값: false (클래식하고 눈이 편한 마인크래프트 본연의 복셀 렌더링)
    private static let lightingEffectKey = "isLightingEffectEnabled"

    public static var isLightingEffectEnabled: Bool {
        get {
            // UserDefaults에 저장된 적이 없으면 false(기본값 OFF) 반환
            return UserDefaults.standard.bool(forKey: lightingEffectKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lightingEffectKey)
        }
    }

    /// 세분화된 밝기 프리셋 (20% ~ 150%) - 기존 '매우 밝게'(150%)를 100% 보통 기준으로 승격
    public static let darkest: Double = 0.20        // 20% (진짜 어두운 심야/동굴 분위기)
    public static let dark: Double = 0.50           // 50% (차분하게 어두운 조명)
    public static let slightlyDark: Double = 0.75   // 75% (약간 은은한 조명)
    public static let normal: Double = 1.00         // 100% (기본값 - 기존의 매우 밝게 150% 광량)
    public static let slightlyBright: Double = 1.25 // 125% (화사한 고광량 조명)
    public static let bright: Double = 1.50         // 150% (초고광량 조명)

    public static let presets: [(title: String, level: Double)] = [
        ("🌑 가장 어둡게 (20%)", darkest),
        ("🌘 어둡게 (50%)", dark),
        ("🌗 약간 어둡게 (75%)", slightlyDark),
        ("🌕 보통 (100%)", normal),
        ("🌖 약간 밝게 (125%)", slightlyBright),
        ("☀️ 매우 밝게 (150%)", bright)
    ]

    /// UserDefaults 키 (기본값 1.0 = 기존 룩 그대로).
    private static let key = "stageBrightness"

    /// 현재 밝기 배율 (get/set 모두 UserDefaults와 동기화).
    public static var level: Double {
        get {
            if let saved = UserDefaults.standard.object(forKey: key) as? Double {
                return max(0.1, min(2.5, saved))
            }
            return normal
        }
        set {
            let clamped = max(0.1, min(2.5, newValue))
            UserDefaults.standard.set(clamped, forKey: key)
        }
    }

    /// 활성 Scene 관리 (약참조로 메모리 누수 없이 전체 뷰 동기화)
    private static let activeScenes = NSHashTable<SCNScene>.weakObjects()

    public static func register(scene: SCNScene) {
        activeScenes.add(scene)
        apply(to: scene)
    }

    public static func applyToAll() {
        for scene in activeScenes.allObjects {
            apply(to: scene)
        }
    }

    /// 스테이지 조명을 배율 및 광원 효과 on/off에 맞게 제어한다.
    public static func apply(to scene: SCNScene) {
        let lvl = level
        let effectsOn = isLightingEffectEnabled
        let effectiveLvl = lvl * 1.50 // 기존 '매우 밝게'(150%)를 새로운 100% 기준으로 승격

        if effectsOn {
            scene.lightingEnvironment.contents = stageEnvironmentImage
            scene.lightingEnvironment.intensity = 0.25 * CGFloat(effectiveLvl)
        } else {
            scene.lightingEnvironment.contents = nil
            scene.lightingEnvironment.intensity = 0.0
        }

        scene.rootNode.enumerateHierarchy { node, _ in
            if let camera = node.camera {
                camera.wantsHDR = effectsOn
                camera.exposureOffset = effectsOn ? (-0.4 + (effectiveLvl - 1.0) * 0.7) : 0.0
            }
            if let light = node.light {
                if node.name == "stageRimLight" {
                    node.isHidden = !effectsOn
                    light.intensity = 1000.0 * CGFloat(effectiveLvl)
                } else if node.name == "stageKeyLight" {
                    light.castsShadow = effectsOn
                    light.color = effectsOn ? NSColor(white: 0.85, alpha: 1.0) : NSColor(white: 0.50, alpha: 1.0)
                    light.intensity = 1000.0 * CGFloat(effectiveLvl)
                } else if node.name == "stageAmbientLight" {
                    light.color = effectsOn ? NSColor(white: 0.50, alpha: 1.0) : NSColor(white: 0.50, alpha: 1.0)
                    light.intensity = 1000.0 * CGFloat(effectiveLvl)
                } else {
                    light.intensity = 1000.0 * CGFloat(effectiveLvl)
                }
            }
            if node.name == "stageShadowCatcher" {
                node.isHidden = !effectsOn
            }
            if let geometry = node.geometry {
                for mat in geometry.materials {
                    if mat.lightingModel == .constant || mat.lightingModel == .shadowOnly {
                        continue
                    }
                    mat.lightingModel = effectsOn ? .physicallyBased : .lambert
                }
            }
        }
    }
}
