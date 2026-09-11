import AppKit
import SceneKit
import CoreGraphics

/// 몹 복셀용 결정적 픽셀아트 텍스처 유틸리티.
public enum MobTexture {
    /// 시드 고정 난수로 픽셀을 칠한 NSImage를 만든다.
    /// 기본 캔버스는 32x32이며, paint 클로저는 0..<width, 0..<height 좌표를 받는다.
    /// 기존 몹 클로저(Creeper/Enderman/Skeleton)는 x, y를 무시하고 난수 r와 기본색만 쓰므로
    /// 해상도와 무관하게 동일한 통계적 패턴을 유지한다.
    /// - Example: `MobTexture.material(seed: 7) { _, _, r in r < 0.5 ? .green : .darkGreen }`
    public static func image(width: Int = 32, height: Int = 32, seed: UInt32, paint: (Int, Int, Double) -> NSColor) -> NSImage {
        let size = NSSize(width: width, height: height)
        let img = NSImage(size: size)
        var rng = Mulberry32(state: seed)
        img.lockFocus()
        for y in 0..<height {
            for x in 0..<width {
                let r = rng.next()
                paint(x, y, r).setFill()
                NSRect(x: x, y: y, width: 1, height: 1).fill()
            }
        }
        img.unlockFocus()
        return img
    }

    /// 이미지를 픽셀풍 SCNMaterial로 감싼다.
    public static func material(image: NSImage) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = image
        mat.diffuse.magnificationFilter = .nearest
        mat.diffuse.minificationFilter = .linear
        mat.diffuse.mipFilter = .linear
        mat.lightingModel = .physicallyBased
        mat.roughness.contents = 1.0
        mat.metalness.contents = 0.0
        return mat
    }

    /// 픽셀을 칠하고 바로 픽셀풍 SCNMaterial을 만든다.
    public static func material(width: Int = 32, height: Int = 32, seed: UInt32, paint: (Int, Int, Double) -> NSColor) -> SCNMaterial {
        material(image: image(width: width, height: height, seed: seed, paint: paint))
    }

    /// 색상을 배율만큼 밝게/어둡게 바꾼다.
    public static func shade(color: NSColor, by factor: CGFloat) -> NSColor {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        // factor > 1 밝게, < 1 어둡게 (0...1 클램프)
        return NSColor(
            red: min(max(rgb.redComponent * factor, 0), 1),
            green: min(max(rgb.greenComponent * factor, 0), 1),
            blue: min(max(rgb.blueComponent * factor, 0), 1),
            alpha: rgb.alphaComponent
        )
    }

    /// 같은 시드에서 항상 같은 수열을 내는 난수기.
    struct Mulberry32 {
        var state: UInt32

        mutating func next() -> Double {
            state &+= 0x6D2B79F5
            var t = state
            t = (t ^ (t >> 15)) &* (t | 1)
            t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
            return Double((t ^ (t >> 14)) >> 0) / Double(UInt32.max)
        }
    }
}
