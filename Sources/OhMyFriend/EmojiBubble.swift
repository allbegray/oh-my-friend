import AppKit
import SceneKit
import CoreGraphics

// 3D 머리 위 말풍선: SCNText는 컬러 이모지(비트맵 글리프)를 벡터 지오메트리로
// 변환하지 못해 빈 박스가 된다. 대신 AppKit 텍스트 렌더링(캐스케이드 정상)으로
// NSImage에 그린 뒤 SCNPlane 텍스처+빌보드로 띄운다. 문자열별 1회 캐시.
public enum EmojiBubble {
    private static var cache: [String: NSImage] = [:]

    public static func image(for text: String) -> NSImage {
        if let hit = cache[text] {
            return hit
        }
        let font = NSFont.systemFont(ofSize: 64)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let str = text as NSString
        var size = str.size(withAttributes: attrs)
        size.width = ceil(size.width) + 24
        size.height = ceil(size.height) + 16
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        str.draw(at: NSPoint(x: 12, y: 8), withAttributes: attrs)
        img.unlockFocus()
        cache[text] = img
        return img
    }

    public static func node(for text: String, worldHeight: CGFloat = 0.5) -> SCNNode {
        let img = image(for: text)
        let aspect = img.size.width / max(img.size.height, 1)
        let plane = SCNPlane(width: worldHeight * aspect, height: worldHeight)
        let mat = SCNMaterial()
        mat.diffuse.contents = img
        mat.lightingModel = .constant
        mat.transparencyMode = .default
        plane.firstMaterial = mat
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        return node
    }
}
