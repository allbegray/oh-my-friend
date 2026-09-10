import AppKit

// MARK: - 화면 공간에 놓인 TNT 블록 (마인크래프트 primed TNT)
// 창 표면에 내려놓은 TNT를 작은 투명 패널로 그린다. 도화선 진행에 따라 하얗게 점멸한다.
public final class TNTEntityWindow: NSPanel {
    private let tntView: TNTEntityView

    /// - Parameter screenPoint: TNT 블록 중심의 화면(Cocoa) 좌표
    public init(at screenPoint: CGPoint) {
        let side: CGFloat = 72
        let frameRect = CGRect(x: screenPoint.x - side / 2, y: screenPoint.y - side / 2, width: side, height: side)
        tntView = TNTEntityView(frame: NSRect(origin: .zero, size: frameRect.size))

        super.init(
            contentRect: frameRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = tntView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setFuseProgress(_ progress: CGFloat) {
        tntView.fuseProgress = min(1, max(0, progress))
    }
}

// MARK: - TNT 픽셀아트 뷰
final class TNTEntityView: NSView {
    var fuseProgress: CGFloat = 0 {
        didSet {
            if fuseProgress != oldValue {
                needsDisplay = true
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let side = min(bounds.width, bounds.height) - 14
        let block = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )

        // TNT 텍스처: 빨간 블록
        ctx.setFillColor(NSColor(srgbRed: 0.80, green: 0.22, blue: 0.14, alpha: 1).cgColor)
        ctx.fill(block)

        // 아래/오른쪽 모서리 음영 (복셀 느낌)
        ctx.setFillColor(NSColor(white: 0, alpha: 0.18).cgColor)
        ctx.fill(CGRect(x: block.minX, y: block.minY, width: block.width, height: side * 0.06))
        ctx.fill(CGRect(x: block.maxX - side * 0.06, y: block.minY, width: side * 0.06, height: block.height))

        // 하얀 밴드 (세로 중앙)
        let bandHeight = side * 0.30
        let band = CGRect(x: block.minX, y: block.midY - bandHeight / 2, width: block.width, height: bandHeight)
        ctx.setFillColor(NSColor(white: 0.93, alpha: 1).cgColor)
        ctx.fill(band)

        // "TNT" 픽셀 글자 (밴드 안, 빨간색)
        drawPixelText(ctx, "TNT", in: band.insetBy(dx: side * 0.10, dy: bandHeight * 0.16))

        // 도화선 점멸: primed TNT처럼 온/오프로 끊어서 하얗게 (진행에 따라 빨라진다)
        let p = min(1, max(0, fuseProgress))
        let phase = 2 * CGFloat.pi * (8 * p + 4 * p * p)
        if sin(phase) > 0 {
            let alpha = 0.45 + 0.35 * p
            ctx.setFillColor(NSColor(white: 1, alpha: alpha).cgColor)
            ctx.fill(block)
        }
    }

    /// 3x5 픽셀 폰트로 "TNT"를 그린다
    private func drawPixelText(_ ctx: CGContext, _ text: String, in rect: CGRect) {
        let glyphs: [Character: [[Int]]] = [
            "T": [[1, 1, 1], [0, 1, 0], [0, 1, 0], [0, 1, 0], [0, 1, 0]],
            "N": [[1, 0, 1], [1, 1, 1], [1, 1, 1], [1, 0, 1], [1, 0, 1]],
        ]
        let glyphWidth = 3
        let glyphHeight = 5
        let spacing = 1
        let totalUnits = text.count * glyphWidth + max(0, text.count - 1) * spacing
        let unit = min(rect.width / CGFloat(totalUnits), rect.height / CGFloat(glyphHeight))
        let startX = rect.midX - (CGFloat(totalUnits) * unit) / 2
        let startY = rect.midY - (CGFloat(glyphHeight) * unit) / 2

        ctx.setFillColor(NSColor(srgbRed: 0.80, green: 0.22, blue: 0.14, alpha: 1).cgColor)
        for (i, ch) in text.enumerated() {
            guard let rows = glyphs[ch] else { continue }
            for (rowIndex, row) in rows.enumerated() {
                for (colIndex, on) in row.enumerated() where on == 1 {
                    let x = startX + CGFloat(i * (glyphWidth + spacing) + colIndex) * unit
                    let y = startY + CGFloat(glyphHeight - 1 - rowIndex) * unit
                    ctx.fill(CGRect(x: x, y: y, width: unit, height: unit))
                }
            }
        }
    }
}
