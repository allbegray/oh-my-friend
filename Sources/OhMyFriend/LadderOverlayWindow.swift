import AppKit

// MARK: - 사다리 등반 연출 오버레이
// 캐릭터 창(캐릭터와 함께 이동)과 달리 화면 위 고정 위치에 머무는 투명 패널.
// 창문 발판에서 아래 발판까지 내려가는 동안 두 개의 레일과 가로대를 그려 사다리를 표현하고,
// 가로대는 캐릭터가 내려간 만큼만 아래로 자라난다.
public final class LadderOverlayWindow: NSPanel {
    private let ladderView: LadderEffectView
    private var isRetiring = false

    /// - Parameter ladderRect: 사다리가 차지할 Cocoa 좌표 영역 (가로대 하한 ~ 창문 발판 상단)
    public init(ladderRect: CGRect) {
        ladderView = LadderEffectView(frame: NSRect(origin: .zero, size: ladderRect.size))

        super.init(
            contentRect: ladderRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 등반하는 캐릭터 창(.floating)보다 한 단계 아래, 대상 앱 창보다는 위
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = ladderView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 사다리 영역을 갱신한다 (창문이 움직이면 사다리도 따라 이동)
    public func update(ladderRect: CGRect) {
        guard !isRetiring else { return }

        if frame != ladderRect {
            setFrame(ladderRect, display: true)
        }
    }

    /// 등반 종료: 페이드아웃 후 창을 닫는다
    public func retire() {
        guard !isRetiring else { return }
        isRetiring = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            self?.close()
        }
    }

    /// 등반 중단: 즉시 정리한다
    public func cancel() {
        isRetiring = true
        close()
    }
}

// MARK: - 사다리를 직접 그리는 뷰
public final class LadderEffectView: NSView {
    private let railWidth: CGFloat = 6.0
    private let railInset: CGFloat = 14.0
    private let rungHeight: CGFloat = 4.5
    private let rungSpacing: CGFloat = 16.0

    private let railColor = NSColor(srgbRed: 0.545, green: 0.353, blue: 0.169, alpha: 1.0)
    private let rungColor = NSColor(srgbRed: 0.663, green: 0.439, blue: 0.235, alpha: 1.0)
    private let outlineColor = NSColor(srgbRed: 0.290, green: 0.184, blue: 0.078, alpha: 1.0)

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let bounds = self.bounds
        let centerX = bounds.midX
        let leftRail = centerX - railInset - railWidth / 2.0
        let rightRail = centerX + railInset - railWidth / 2.0

        // 1. 두 개의 레일 (전체 길이)
        for railX in [leftRail, rightRail] {
            let rect = CGRect(x: railX, y: bounds.minY, width: railWidth, height: bounds.height)
            drawVoxelRect(ctx, rect: rect, fill: railColor)
        }

        // 2. 가로대 (설치 시점부터 전체가 생성되어 있다)
        let rungWidth = (rightRail + railWidth) - leftRail
        var y = bounds.maxY - rungSpacing
        while y > bounds.minY + rungHeight {
            let rect = CGRect(x: leftRail, y: y, width: rungWidth, height: rungHeight)
            drawVoxelRect(ctx, rect: rect, fill: rungColor)
            y -= rungSpacing
        }
    }

    private func drawVoxelRect(_ ctx: CGContext, rect: CGRect, fill: NSColor) {
        ctx.saveGState()
        ctx.setFillColor(fill.cgColor)
        ctx.fill(rect)
        ctx.setStrokeColor(outlineColor.cgColor)
        ctx.setLineWidth(1.0)
        ctx.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
        ctx.restoreGState()
    }
}
