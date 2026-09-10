import AppKit
import SceneKit
import CoreGraphics

public enum BodyPart {
    case head
    case torso
    case rightArm
    case leftArm
    case rightLeg
    case leftLeg
}

public final class SkinTexture {
    public let image: NSImage
    private let cgImage: CGImage
    private let isClassic32: Bool

    public init?(image: NSImage) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        self.image = image
        self.cgImage = cg
        self.isClassic32 = (cg.height == 32)
    }

    public static func load(from url: URL) -> SkinTexture? {
        guard let img = NSImage(contentsOf: url) else { return nil }
        return SkinTexture(image: img)
    }

    /// SCNBox의 6개 materials 순서:
    /// index 0: Front (+Z)
    /// index 1: Right (+X)
    /// index 2: Back (-Z)
    /// index 3: Left (-X)
    /// index 4: Top (+Y)
    /// index 5: Bottom (-Y)
    public func materials(for part: BodyPart) -> [SCNMaterial] {
        let crops = rects(for: part)
        // crops 순서: [front, right, back, left, top, bottom]
        return crops.map { rect in
            let mat = SCNMaterial()
            if let subCG = crop(rect: rect) {
                let subImage = NSImage(cgImage: subCG, size: NSSize(width: rect.width, height: rect.height))
                mat.diffuse.contents = subImage
                mat.diffuse.magnificationFilter = .nearest
                mat.diffuse.minificationFilter = .nearest
                mat.diffuse.mipFilter = .none
                mat.roughness.contents = 1.0
                mat.lightingModel = .lambert
            }
            return mat
        }
    }

    /// 2차 레이어 (오버레이/모자/자켓/소매/바지 외투) SCNMaterial 배열 (Front, Right, Back, Left, Top, Bottom)
    /// 투명한 픽셀이 하나도 없거나(미사용) 32px 클래식 스킨의 미지원 부위인 경우 nil 반환
    public func overlayMaterials(for part: BodyPart) -> [SCNMaterial]? {
        guard let crops = overlayRects(for: part) else { return nil }

        // 투명 픽셀 검사: 6개 면 전체에 유의미한 가시 픽셀이 하나라도 있는지 확인
        var hasAnyPixel = false
        var croppedImages: [CGImage?] = []
        croppedImages.reserveCapacity(crops.count)

        for rect in crops {
            if let subCG = crop(rect: rect) {
                croppedImages.append(subCG)
                if !hasAnyPixel && hasVisiblePixels(in: subCG) {
                    hasAnyPixel = true
                }
            } else {
                croppedImages.append(nil)
            }
        }

        guard hasAnyPixel else { return nil }

        return zip(crops, croppedImages).map { rect, subCG in
            let mat = SCNMaterial()
            if let subCG = subCG {
                let subImage = NSImage(cgImage: subCG, size: NSSize(width: rect.width, height: rect.height))
                mat.diffuse.contents = subImage
                mat.diffuse.magnificationFilter = .nearest
                mat.diffuse.minificationFilter = .nearest
                mat.diffuse.mipFilter = .none
                mat.roughness.contents = 1.0
                mat.lightingModel = .lambert
                mat.isDoubleSided = true
                mat.blendMode = .alpha
                mat.writesToDepthBuffer = true
                mat.readsFromDepthBuffer = true
            }
            return mat
        }
    }

    private func overlayRects(for part: BodyPart) -> [CGRect]? {
        // Minecraft 1.8+ 2nd layer UV coordinates in 64x64 skin
        // Order: [Front, Right, Back, Left, Top, Bottom]
        switch part {
        case .head:
            // Hat layer exists in both 64x64 and classic 64x32
            return [
                CGRect(x: 40, y: 8, width: 8, height: 8),    // Front
                CGRect(x: 32, y: 8, width: 8, height: 8),    // Right
                CGRect(x: 56, y: 8, width: 8, height: 8),    // Back
                CGRect(x: 48, y: 8, width: 8, height: 8),    // Left
                CGRect(x: 40, y: 0, width: 8, height: 8),    // Top
                CGRect(x: 48, y: 0, width: 8, height: 8)     // Bottom
            ]
        case .torso:
            guard !isClassic32 else { return nil }
            return [
                CGRect(x: 20, y: 36, width: 8, height: 12), // Front
                CGRect(x: 16, y: 36, width: 4, height: 12), // Right
                CGRect(x: 32, y: 36, width: 8, height: 12), // Back
                CGRect(x: 28, y: 36, width: 4, height: 12), // Left
                CGRect(x: 20, y: 32, width: 8, height: 4),  // Top
                CGRect(x: 28, y: 32, width: 8, height: 4)   // Bottom
            ]
        case .rightArm:
            guard !isClassic32 else { return nil }
            return [
                CGRect(x: 44, y: 36, width: 4, height: 12), // Front
                CGRect(x: 40, y: 36, width: 4, height: 12), // Right
                CGRect(x: 52, y: 36, width: 4, height: 12), // Back
                CGRect(x: 48, y: 36, width: 4, height: 12), // Left
                CGRect(x: 44, y: 32, width: 4, height: 4),  // Top
                CGRect(x: 48, y: 32, width: 4, height: 4)   // Bottom
            ]
        case .leftArm:
            guard !isClassic32 else { return nil }
            return [
                CGRect(x: 52, y: 52, width: 4, height: 12), // Front
                CGRect(x: 48, y: 52, width: 4, height: 12), // Right
                CGRect(x: 60, y: 52, width: 4, height: 12), // Back
                CGRect(x: 56, y: 52, width: 4, height: 12), // Left
                CGRect(x: 52, y: 48, width: 4, height: 4),  // Top
                CGRect(x: 56, y: 48, width: 4, height: 4)   // Bottom
            ]
        case .rightLeg:
            guard !isClassic32 else { return nil }
            return [
                CGRect(x: 4, y: 36, width: 4, height: 12),  // Front
                CGRect(x: 0, y: 36, width: 4, height: 12),  // Right
                CGRect(x: 12, y: 36, width: 4, height: 12), // Back
                CGRect(x: 8, y: 36, width: 4, height: 12),  // Left
                CGRect(x: 4, y: 32, width: 4, height: 4),   // Top
                CGRect(x: 8, y: 32, width: 4, height: 4)    // Bottom
            ]
        case .leftLeg:
            guard !isClassic32 else { return nil }
            return [
                CGRect(x: 4, y: 52, width: 4, height: 12),  // Front
                CGRect(x: 0, y: 52, width: 4, height: 12),  // Right
                CGRect(x: 12, y: 52, width: 4, height: 12), // Back
                CGRect(x: 8, y: 52, width: 4, height: 12),  // Left
                CGRect(x: 4, y: 48, width: 4, height: 4),   // Top
                CGRect(x: 8, y: 48, width: 4, height: 4)    // Bottom
            ]
        }
    }

    private func hasVisiblePixels(in image: CGImage) -> Bool {
        let width = image.width
        let height = image.height
        guard width > 0 && height > 0 else { return false }

        var data = [UInt32](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return true // Fallback: try rendering if context creation fails
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        for pixel in data {
            let alpha = (pixel >> 24) & 0xFF
            if alpha > 15 {
                return true
            }
        }
        return false
    }

    private func rects(for part: BodyPart) -> [CGRect] {
        // Minecraft skin UV coordinates (X, Y, W, H) in a 64x64 or 64x32 texture
        // Order: [Front, Right, Back, Left, Top, Bottom]
        switch part {
        case .head:
            return [
                CGRect(x: 8, y: 8, width: 8, height: 8),    // Front
                CGRect(x: 0, y: 8, width: 8, height: 8),    // Right
                CGRect(x: 24, y: 8, width: 8, height: 8),   // Back
                CGRect(x: 16, y: 8, width: 8, height: 8),   // Left
                CGRect(x: 8, y: 0, width: 8, height: 8),    // Top
                CGRect(x: 16, y: 0, width: 8, height: 8)    // Bottom
            ]
        case .torso:
            return [
                CGRect(x: 20, y: 20, width: 8, height: 12), // Front
                CGRect(x: 16, y: 20, width: 4, height: 12), // Right
                CGRect(x: 32, y: 20, width: 8, height: 12), // Back
                CGRect(x: 28, y: 20, width: 4, height: 12), // Left
                CGRect(x: 20, y: 16, width: 8, height: 4),  // Top
                CGRect(x: 28, y: 16, width: 8, height: 4)   // Bottom
            ]
        case .rightArm:
            return [
                CGRect(x: 44, y: 20, width: 4, height: 12), // Front
                CGRect(x: 40, y: 20, width: 4, height: 12), // Right
                CGRect(x: 52, y: 20, width: 4, height: 12), // Back
                CGRect(x: 48, y: 20, width: 4, height: 12), // Left
                CGRect(x: 44, y: 16, width: 4, height: 4),  // Top
                CGRect(x: 48, y: 16, width: 4, height: 4)   // Bottom
            ]
        case .leftArm:
            if !isClassic32 {
                return [
                    CGRect(x: 36, y: 52, width: 4, height: 12), // Front
                    CGRect(x: 32, y: 52, width: 4, height: 12), // Right
                    CGRect(x: 44, y: 52, width: 4, height: 12), // Back
                    CGRect(x: 40, y: 52, width: 4, height: 12), // Left
                    CGRect(x: 36, y: 48, width: 4, height: 4),  // Top
                    CGRect(x: 40, y: 48, width: 4, height: 4)   // Bottom
                ]
            } else {
                // Classic 64x32 mirrors right arm
                return rects(for: .rightArm)
            }
        case .rightLeg:
            return [
                CGRect(x: 4, y: 20, width: 4, height: 12),  // Front
                CGRect(x: 0, y: 20, width: 4, height: 12),  // Right
                CGRect(x: 12, y: 20, width: 4, height: 12), // Back
                CGRect(x: 8, y: 20, width: 4, height: 12),  // Left
                CGRect(x: 4, y: 16, width: 4, height: 4),   // Top
                CGRect(x: 8, y: 16, width: 4, height: 4)    // Bottom
            ]
        case .leftLeg:
            if !isClassic32 {
                return [
                    CGRect(x: 20, y: 52, width: 4, height: 12), // Front
                    CGRect(x: 16, y: 52, width: 4, height: 12), // Right
                    CGRect(x: 28, y: 52, width: 4, height: 12), // Back
                    CGRect(x: 24, y: 52, width: 4, height: 12), // Left
                    CGRect(x: 20, y: 48, width: 4, height: 4),  // Top
                    CGRect(x: 24, y: 48, width: 4, height: 4)   // Bottom
                ]
            } else {
                // Classic 64x32 mirrors right leg
                return rects(for: .rightLeg)
            }
        }
    }

    private func crop(rect: CGRect) -> CGImage? {
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)

        // Scale rect if image is not exactly 64x64 (e.g. 128x128 HD skins)
        let scaleX = imgW / 64.0
        let scaleY = imgH / (isClassic32 ? 32.0 : 64.0)

        // Note: CGImage cropping uses CoreGraphics coordinate system (0,0 at bottom-left in some contexts, but cropping with cropping(to:) uses pixel coords starting at top-left)
        let scaledRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.size.width * scaleX,
            height: rect.size.height * scaleY
        )

        return cgImage.cropping(to: scaledRect)
    }
}

// MARK: - Built-in Skins Generator
public enum BuiltinSkinType: String, CaseIterable {
    case steve = "Steve"
    case alex = "Alex"
    case zombie = "Zombie"

    public var displayName: String {
        switch self {
        case .steve: return "스마트 스티브 (Steve)"
        case .alex: return "알렉스 (Alex)"
        case .zombie: return "귀여운 좀비 (Zombie)"
        }
    }
}

public struct BuiltinSkinGenerator {
    public static func makeSkin(type: BuiltinSkinType) -> NSImage {
        let width = 64
        let height = 64
        var pixels = [UInt32](repeating: 0, count: width * height)

        func color(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) -> UInt32 {
            // Little-endian RGBA
            return UInt32(r) | (UInt32(g) << 8) | (UInt32(b) << 16) | (UInt32(a) << 24)
        }

        func fill(x: Int, y: Int, w: Int, h: Int, col: UInt32) {
            for py in y..<min(y + h, height) {
                for px in x..<min(x + w, width) {
                    pixels[py * width + px] = col
                }
            }
        }

        func set(x: Int, y: Int, col: UInt32) {
            if x >= 0 && x < width && y >= 0 && y < height {
                pixels[y * width + x] = col
            }
        }

        let skinCol: UInt32
        let hairCol: UInt32
        let eyeCol: UInt32
        let shirtCol: UInt32
        let shirtDarkCol: UInt32
        let pantsCol: UInt32
        let pantsDarkCol: UInt32
        let shoeCol: UInt32

        switch type {
        case .steve:
            skinCol = color(0xC4, 0x8E, 0x6C)
            hairCol = color(0x45, 0x2A, 0x14)
            eyeCol = color(0x3B, 0x43, 0xA3)
            shirtCol = color(0x00, 0x9E, 0x9B)
            shirtDarkCol = color(0x00, 0x80, 0x80)
            pantsCol = color(0x28, 0x36, 0x76)
            pantsDarkCol = color(0x1D, 0x27, 0x57)
            shoeCol = color(0x50, 0x50, 0x50)

        case .alex:
            skinCol = color(0xDB, 0xA0, 0x7D)
            hairCol = color(0xC4, 0x5B, 0x1F)
            eyeCol = color(0x3C, 0x7A, 0x44)
            shirtCol = color(0x58, 0x76, 0x38)
            shirtDarkCol = color(0x43, 0x5B, 0x2A)
            pantsCol = color(0x4B, 0x36, 0x28)
            pantsDarkCol = color(0x38, 0x28, 0x1D)
            shoeCol = color(0x30, 0x24, 0x1B)

        case .zombie:
            skinCol = color(0x56, 0x7F, 0x3D)
            hairCol = color(0x37, 0x51, 0x28)
            eyeCol = color(0x19, 0x19, 0x19)
            shirtCol = color(0x00, 0x84, 0x82)
            shirtDarkCol = color(0x00, 0x65, 0x66)
            pantsCol = color(0x3A, 0x28, 0x63)
            pantsDarkCol = color(0x28, 0x1C, 0x47)
            shoeCol = color(0x40, 0x40, 0x40)
        }

        // 1. HEAD (64x64 map: top/bottom at 8..24, y=0..8; faces at 0..32, y=8..16)
        // Hair top
        fill(x: 8, y: 0, w: 8, h: 8, col: hairCol)
        // Head bottom (neck)
        fill(x: 16, y: 0, w: 8, h: 8, col: skinCol)

        // Head sides: Right (0..8), Front (8..16), Left (16..24), Back (24..32)
        fill(x: 0, y: 8, w: 32, h: 8, col: hairCol)
        // Face area on Front
        fill(x: 8, y: 10, w: 8, h: 6, col: skinCol)
        // Eyes
        set(x: 9, y: 12, col: color(255, 255, 255))
        set(x: 10, y: 12, col: eyeCol)
        set(x: 13, y: 12, col: eyeCol)
        set(x: 14, y: 12, col: color(255, 255, 255))
        // Nose & Mouth (or beard)
        set(x: 11, y: 13, col: color(0x9E, 0x6E, 0x53))
        set(x: 12, y: 13, col: color(0x9E, 0x6E, 0x53))
        if type == .steve {
            fill(x: 10, y: 14, w: 4, h: 2, col: color(0x45, 0x2A, 0x14))
            fill(x: 11, y: 14, w: 2, h: 1, col: color(0x9E, 0x6E, 0x53))
        } else {
            fill(x: 11, y: 14, w: 2, h: 1, col: color(0x8C, 0x48, 0x3E))
        }

        // 2. TORSO (w=8, h=12, d=4)
        // Top & Bottom (y=16..20)
        fill(x: 20, y: 16, w: 8, h: 4, col: shirtCol)
        fill(x: 28, y: 16, w: 8, h: 4, col: pantsCol)
        // Sides (y=20..32)
        fill(x: 16, y: 20, w: 24, h: 12, col: shirtCol)
        // Front neck collar opening
        fill(x: 22, y: 20, w: 4, h: 2, col: skinCol)
        // Shading on lower torso
        fill(x: 16, y: 30, w: 24, h: 2, col: shirtDarkCol)

        // 3. RIGHT ARM (w=4, h=12, d=4)
        fill(x: 44, y: 16, w: 4, h: 4, col: shirtCol)
        fill(x: 48, y: 16, w: 4, h: 4, col: skinCol) // hand bottom
        fill(x: 40, y: 20, w: 16, h: 4, col: shirtCol) // sleeve
        fill(x: 40, y: 24, w: 16, h: 8, col: skinCol)  // bare arm

        // 4. LEFT ARM
        fill(x: 36, y: 48, w: 4, h: 4, col: shirtCol)
        fill(x: 40, y: 48, w: 4, h: 4, col: skinCol)
        fill(x: 32, y: 52, w: 16, h: 4, col: shirtCol)
        fill(x: 32, y: 56, w: 16, h: 8, col: skinCol)

        // 5. RIGHT LEG (w=4, h=12, d=4)
        fill(x: 4, y: 16, w: 4, h: 4, col: pantsCol)
        fill(x: 8, y: 16, w: 4, h: 4, col: shoeCol)
        fill(x: 0, y: 20, w: 16, h: 8, col: pantsCol)
        fill(x: 0, y: 28, w: 16, h: 2, col: pantsDarkCol)
        fill(x: 0, y: 30, w: 16, h: 2, col: shoeCol) // shoes

        // 6. LEFT LEG
        fill(x: 20, y: 48, w: 4, h: 4, col: pantsCol)
        fill(x: 24, y: 48, w: 4, h: 4, col: shoeCol)
        fill(x: 16, y: 52, w: 16, h: 8, col: pantsCol)
        fill(x: 16, y: 60, w: 16, h: 2, col: pantsDarkCol)
        fill(x: 16, y: 62, w: 16, h: 2, col: shoeCol)


        // 7. 2nd Layer (Overlays) for Built-in Skins
        switch type {
        case .alex:
            // Alex's 3D hair strands and ponytail on Hat layer
            // Hat top
            fill(x: 40, y: 0, w: 8, h: 8, col: hairCol)
            // Hat front bangs
            fill(x: 40, y: 8, w: 8, h: 2, col: hairCol)
            set(x: 40, y: 10, col: hairCol)
            set(x: 41, y: 10, col: hairCol)
            set(x: 46, y: 10, col: hairCol)
            set(x: 47, y: 10, col: hairCol)
            // Hat sides (long hair hanging down)
            fill(x: 32, y: 8, w: 8, h: 7, col: hairCol)
            fill(x: 48, y: 8, w: 8, h: 7, col: hairCol)
            // Hat back (ponytail)
            fill(x: 56, y: 8, w: 8, h: 8, col: hairCol)

        case .steve:
            // Steve's 3D hair fringe on Hat layer
            fill(x: 40, y: 0, w: 8, h: 8, col: hairCol)
            fill(x: 40, y: 8, w: 8, h: 2, col: hairCol)
            fill(x: 32, y: 8, w: 8, h: 4, col: hairCol)
            fill(x: 48, y: 8, w: 8, h: 4, col: hairCol)
            fill(x: 56, y: 8, w: 8, h: 5, col: hairCol)

        case .zombie:
            // Zombie's ragged collar and sleeve fringes on jacket
            fill(x: 20, y: 36, w: 8, h: 2, col: shirtDarkCol)
            set(x: 21, y: 38, col: shirtDarkCol)
            set(x: 26, y: 38, col: shirtDarkCol)
        }
        // Create CGImage from pixel array
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let provider = CGDataProvider(data: Data(bytes: pixels, count: pixels.count * 4) as CFData),
              let cg = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return NSImage()
        }

        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }
}
