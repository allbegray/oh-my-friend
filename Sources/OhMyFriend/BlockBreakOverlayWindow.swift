import AppKit

// MARK: - TNT 폭파 연출 오버레이
// 대상 앱 창 위에 투명 패널을 띄워 ① 도화선 점멸(마인크래프트 primed TNT처럼 하얗게 펄스)
// ② 폭발 섬광·연기·불똥과 함께 창 전체가 블록 파편으로 비산하는 모습을 그린다.
public final class BlockBreakOverlayWindow: NSPanel {
    /// 모든 창이 함께 쓸 수 있는 파편 예산 (2x 화면 기준, 프레임당).
    /// 그리기 비용이 파편 수에 거의 선형이라(실측 @2x 1880x1860 패널: 1980개 14.2ms / 900개 6.9ms / 450개 4.0ms)
    /// 캐릭터·물리·창 합성이 함께 도는 16.7ms 프레임 안에 들어오는 값으로 잡는다.
    public static let debrisBudgetTotal = 900

    /// 창이 아무리 많아도 한 창에 남겨 두는 최소 파편 수 (너무 적으면 "부서짐"으로 읽히지 않는다)
    public static let minimumDebrisPerWindow = 60

    private let effectView: BlockBreakEffectView

    /// 파편 연출이 끝난 뒤 호출 (창은 자동으로 닫힘)
    public var onBreakFinished: (() -> Void)?

    /// - Parameters:
    ///   - windowRect: 공격 대상 창의 Cocoa 좌표 프레임
    ///   - screen: 대상 창이 놓인 화면 (파편 낙하 공간 계산용)
    ///   - debrisBudget: 이 창에 허용된 파편 수 상한 (2x 화면 기준)
    public init(over windowRect: CGRect, on screen: NSScreen, debrisBudget: Int) {
        let visible = screen.visibleFrame

        // 파편이 창 밖으로 멀리 날아갈 수 있도록 화면 경계까지 여백을 크게 잡는다.
        // (오버레이 패널 프레임이 그대로 드로잉 클리핑 경계가 되기 때문에, 여백이 곧 비산 범위다)
        let leftRoom = min(340, max(60, windowRect.minX - visible.minX))
        let rightRoom = min(340, max(60, visible.maxX - windowRect.maxX))
        let topRoom = min(420, max(60, visible.maxY - windowRect.maxY))
        let bottomRoom = min(640, max(120, windowRect.minY - visible.minY))
        let frameRect = CGRect(
            x: windowRect.minX - leftRoom,
            y: windowRect.minY - bottomRoom,
            width: windowRect.width + leftRoom + rightRoom,
            height: windowRect.height + topRoom + bottomRoom
        )

        effectView = BlockBreakEffectView(
            windowRectInLocal: CGRect(x: leftRoom, y: bottomRoom, width: windowRect.width, height: windowRect.height),
            debrisBudget: debrisBudget
        )

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

        contentView = effectView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 도화선 진행 0...1 — 창이 primed TNT처럼 하얗게 점멸한다
    public func showFuse(progress: CGFloat) {
        effectView.fuseProgress = min(1, max(0, progress))
    }

    /// 폭발: 화면 좌표의 TNT 위치에서 섬광·연기와 함께 창이 블록 파편으로 터진다
    public func explode(at tntScreenPoint: CGPoint) {
        let local = CGPoint(x: tntScreenPoint.x - frame.minX, y: tntScreenPoint.y - frame.minY)
        effectView.beginExplosion(atLocal: local) { [weak self] in
            guard let self = self else { return }
            self.close()
            self.onBreakFinished?()
        }
    }

    /// 연출 중단 (드래그/낙하로 중단된 경우)
    public func cancel() {
        effectView.cancelAnimation()
        close()
    }
}

// MARK: - 연출을 직접 그리는 뷰
public final class BlockBreakEffectView: NSView {
    /// 도화선 진행 0...1 (0이면 점멸 없음)
    /// 하얀 사각형은 한 번만 그리고, 점멸 밝기는 창 alphaValue로 조절한다.
    /// (창 alpha는 창 서버가 GPU로 합성하므로 매 프레임 흰 사각형을 알파 블렌딩으로 다시 칠하던 비용이 사라진다.
    ///  실측 @2x: 1200x800 알파 채우기 = 6.3ms/프레임 → 0ms)
    public var fuseProgress: CGFloat = 0 {
        didSet {
            guard fuseProgress != oldValue else { return }
            // 마인크래프트 primed TNT처럼 온/오프로 끊어서 점멸 (진행에 따라 점점 빨라진다)
            guard sin(BlockBreakEffectView.fusePhase(fuseProgress)) > 0 else {
                window?.alphaValue = 0
                return
            }
            if !fuseRectDrawn {
                fuseRectDrawn = true
                needsDisplay = true
            }
            window?.alphaValue = 0.45 + 0.35 * min(1, max(0, fuseProgress))
        }
    }

    private static func fusePhase(_ progress: CGFloat) -> CGFloat {
        let p = min(1, max(0, progress))
        return 2 * CGFloat.pi * (8 * p + 4 * p * p)
    }

    private var fuseRectDrawn = false

    private let windowRectInLocal: CGRect
    /// 2x 화면 기준 파편 수 상한 (실제 허용치는 화면 배율에 따라 4배까지 늘어난다)
    private let debrisBudget: Int

    // 정적 색은 프레임마다 변환하지 않도록 CGColor로 캐시한다 (투명도는 ctx.setAlpha로 일괄 적용)
    private static let highlightColor = NSColor(white: 1, alpha: 0.10).cgColor
    private static let shadeColor = NSColor(white: 0, alpha: 0.12).cgColor

    // 파편 상태
    private struct DebrisBlock {
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var spin: CGFloat
        var spinV: CGFloat
        var color: CGColor
        var delay: CGFloat
    }

    // 폭발 연기 (회색 원이 커지며 사라짐)
    private struct SmokePuff {
        var x: CGFloat
        var y: CGFloat
        var maxRadius: CGFloat
        var alpha: CGFloat
        var delay: CGFloat
    }

    // 폭발 불똥 (주황 사각 파편)
    private struct Spark {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var size: CGFloat
        var delay: CGFloat
    }

    private var debris: [DebrisBlock] = []
    private var smoke: [SmokePuff] = []
    private var sparks: [Spark] = []

    private var explosionPoint: CGPoint = .zero
    private var hasExploded = false
    private var burstTime: TimeInterval = 0
    private var timer: Timer?
    private var onDone: (() -> Void)?

    private static let gravity: CGFloat = 1500.0
    private static let fadeStart: CGFloat = 1.25
    private static let fadeEnd: CGFloat = 1.85
    private static let flashDuration: CGFloat = 0.16
    private static let smokeLife: CGFloat = 0.95
    private static let sparkLife: CGFloat = 0.55

    public init(windowRectInLocal: CGRect, debrisBudget: Int) {
        self.windowRectInLocal = windowRectInLocal
        self.debrisBudget = debrisBudget
        super.init(frame: NSRect(origin: .zero, size: windowRectInLocal.size))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - 폭발 시작

    public func beginExplosion(atLocal point: CGPoint, onDone: @escaping () -> Void) {
        guard !hasExploded else { return }
        hasExploded = true
        window?.alphaValue = 1   // 도화선 점멸로 낮춰 둔 패널 불투명도를 되돌린다
        explosionPoint = point
        self.onDone = onDone
        buildDebris()
        buildExplosionFX()
        burstTime = 0

        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        needsDisplay = true
    }

    public func cancelAnimation() {
        timer?.invalidate()
        timer = nil
        hasExploded = false
        window?.alphaValue = 1
        fuseRectDrawn = false
        fuseProgress = 0
        debris.removeAll()
        smoke.removeAll()
        sparks.removeAll()
        needsDisplay = true
    }

    // MARK: - 창 톤 팔레트 (화면 기록 권한 프롬프트를 띄우지 않도록 실사 캡처 없이 사용)

    private func windowTonePalette() -> [NSColor] {
        // 시스템 라이트/다크와 비슷한 "앱 창" 톤
        let dark = NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if dark {
            return [
                NSColor(white: 0.16, alpha: 1), NSColor(white: 0.23, alpha: 1),
                NSColor(white: 0.30, alpha: 1), NSColor(white: 0.38, alpha: 1),
                NSColor(white: 0.44, alpha: 1), NSColor(srgbRed: 0.22, green: 0.23, blue: 0.29, alpha: 1),
            ]
        }
        return [
            NSColor(white: 0.92, alpha: 1), NSColor(white: 0.97, alpha: 1),
            NSColor(white: 0.86, alpha: 1), NSColor(srgbRed: 0.80, green: 0.82, blue: 0.86, alpha: 1),
            NSColor(srgbRed: 0.70, green: 0.72, blue: 0.77, alpha: 1),
            NSColor(srgbRed: 0.28, green: 0.29, blue: 0.32, alpha: 1), // 텍스트류 다크 파편
        ]
    }

    // MARK: - 파편 생성 (창 크기에 정확히 타일링)

    private func buildDebris() {
        debris.removeAll()
        let win = windowRectInLocal

        // 창 크기에 정확히 맞는 타일 격자 — 남는 가장자리 없이 창 전체를 덮는다
        // 파편 수 상한은 화면 배율에 따라 늘어난다: 1x 화면은 같은 면적을 채우는 픽셀이 1/4이라 4배까지 허용
        let scale = max(1, window?.backingScaleFactor ?? 2)
        let budget = max(24, Int((CGFloat(debrisBudget) * (2.0 / scale) * (2.0 / scale)).rounded()))

        var targetCell: CGFloat = 22.0
        var cols = max(1, Int((win.width / targetCell).rounded()))
        var rows = max(1, Int((win.height / targetCell).rounded()))
        while cols * rows > budget {
            targetCell *= 1.15
            cols = max(1, Int((win.width / targetCell).rounded()))
            rows = max(1, Int((win.height / targetCell).rounded()))
        }
        let cellW = win.width / CGFloat(cols)
        let cellH = win.height / CGFloat(rows)
        // 정사각형 파편을 셀 안에 맞춘다 (작은 셀 기준, 최소 간격 확보)
        let blockSize = max(2, min(cellW, cellH) - 2.0)

        var rng = SplitMix64(seed: 0x9E37_79B9_7F4A_7C15)
        let palette = windowTonePalette()

        func paletteColor(seed: CGFloat) -> NSColor {
            let base = palette[Int(seed * CGFloat(palette.count)) % palette.count]
            let converted = base.usingColorSpace(.deviceRGB) ?? base
            return NSColor(
                srgbRed: converted.redComponent,
                green: converted.greenComponent,
                blue: converted.blueComponent,
                alpha: 1
            )
        }

        for row in 0..<rows {
            for col in 0..<cols {
                let centerX = win.minX + (CGFloat(col) + 0.5) * cellW
                let centerY = win.minY + (CGFloat(row) + 0.5) * cellH

                // 파편마다 창 톤 팔레트에서 색 선택 + 휘도 미세 변동
                var color = paletteColor(seed: rng.range(0, 1))
                let jitter = 0.93 + rng.range(0, 0.14)
                color = NSColor(
                    srgbRed: min(1, color.redComponent * jitter),
                    green: min(1, color.greenComponent * jitter),
                    blue: min(1, color.blueComponent * jitter),
                    alpha: 1
                )

                var block = DebrisBlock(
                    x: centerX,
                    y: centerY,
                    size: blockSize,
                    vx: 0,
                    vy: 0,
                    spin: 0,
                    spinV: rng.range(-9, 9),
                    color: color.cgColor,
                    delay: 0
                )

                // 폭발 순간 거의 동시에(짧은 무작위 편차만) 튄다
                block.delay = 0.02 + rng.range(0, 0.06)

                // TNT 폭발 지점에서 바깥으로 세게 터진다 (+ 모든 파편에 최소 비산)
                let dx = (centerX - explosionPoint.x) / max(win.width / 2, 1)
                let dy = (centerY - explosionPoint.y) / max(win.height / 2, 1)
                let lateralSign: CGFloat = dx >= 0 ? 1 : -1
                block.vx = lateralSign * (abs(dx) * rng.range(220, 560) + rng.range(40, 170)) + rng.range(-50, 50)
                block.vy = abs(dy) * rng.range(140, 300) + rng.range(160, 720)
                debris.append(block)
            }
        }
    }

    private func buildExplosionFX() {
        var rng = SplitMix64(seed: 0x7FF4_9C2B_53D1_8E4F)
        let blast = explosionPoint

        // 연기·불똥은 원 하나/사각형 하나가 곧 채우는 픽셀이라 파편과 똑같이 프레임 비용을 먹는다.
        // 창을 여러 개 동시에 폭파할 때는 파편 예산이 줄어든 만큼 연출 밀도도 함께 낮춘다.
        let intensity = min(1, CGFloat(debrisBudget) / 400)

        // 회색 연기 구름 — 폭발점 주변에서 피어오른다
        smoke.removeAll()
        for _ in 0..<max(5, Int(18 * intensity)) {
            let angle = rng.range(0, 2 * .pi)
            let dist = rng.range(0, 70)
            smoke.append(SmokePuff(
                x: blast.x + cos(angle) * dist,
                y: blast.y + sin(angle) * dist,
                maxRadius: rng.range(26, 68),
                alpha: rng.range(0.35, 0.6),
                delay: rng.range(0, 0.12)
            ))
        }

        // 주황 불똥 — 사방으로 빠르게 튄다
        sparks.removeAll()
        for _ in 0..<max(6, Int(26 * intensity)) {
            let angle = rng.range(0, 2 * .pi)
            let speed = rng.range(240, 780)
            sparks.append(Spark(
                x: blast.x,
                y: blast.y,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                size: rng.range(3, 6.5),
                delay: rng.range(0, 0.08)
            ))
        }
    }

    private func tick() {
        burstTime += 1.0 / 60.0
        let t = CGFloat(burstTime)

        for i in debris.indices {
            let elapsed = t - debris[i].delay
            guard elapsed > 0 else { continue }
            debris[i].vy -= BlockBreakEffectView.gravity * (1.0 / 60.0)
            debris[i].x += debris[i].vx * (1.0 / 60.0)
            debris[i].y += debris[i].vy * (1.0 / 60.0)
            debris[i].spin += debris[i].spinV * (1.0 / 60.0)
        }

        if t >= 2.2 {
            timer?.invalidate()
            timer = nil
            needsDisplay = true
            onDone?()
        } else {
            needsDisplay = true
        }
    }

    // MARK: - 그리기

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        if hasExploded {
            drawExplosion(ctx)
        } else if fuseProgress > 0 {
            drawFuseBlink(ctx)
        }
    }

    // MARK: - 도화선 점멸 (primed TNT처럼 하얗게)

    private func drawFuseBlink(_ ctx: CGContext) {
        // 불투명 흰 사각형을 한 번만 칠한다 — 켜짐/꺼짐은 창 alphaValue가 담당한다
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(windowRectInLocal)
    }

    // MARK: - 폭발 렌더링

    private func drawExplosion(_ ctx: CGContext) {
        let t = CGFloat(burstTime)
        let blast = explosionPoint

        // 1) 연기 구름
        for puff in smoke {
            let elapsed = t - puff.delay
            guard elapsed > 0, elapsed < BlockBreakEffectView.smokeLife else { continue }
            let f = elapsed / BlockBreakEffectView.smokeLife
            let radius = puff.maxRadius * (0.25 + 0.75 * min(1, f * 2.2))
            let alpha = puff.alpha * (1 - f)
            ctx.setFillColor(NSColor(white: 0.42, alpha: alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: puff.x - radius, y: puff.y - radius, width: radius * 2, height: radius * 2))
        }

        // 2) 불똥 (포물선)
        for spark in sparks {
            let elapsed = t - spark.delay
            guard elapsed > 0, elapsed < BlockBreakEffectView.sparkLife else { continue }
            let f = elapsed / BlockBreakEffectView.sparkLife
            let x = spark.x + spark.vx * elapsed
            let y = spark.y + spark.vy * elapsed - 450 * elapsed * elapsed
            let size = spark.size * (1 - f * 0.5)
            ctx.setFillColor(NSColor(srgbRed: 1.0, green: 0.66, blue: 0.22, alpha: 1 - f).cgColor)
            ctx.fill(CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size))
        }

        // 3) 창 블록 파편
        let cullBounds = bounds.insetBy(dx: -48, dy: -48)
        for b in debris {
            let elapsed = t - b.delay
            guard elapsed > 0 else { continue }

            let alpha: CGFloat
            if elapsed <= BlockBreakEffectView.fadeStart {
                alpha = 1
            } else if elapsed >= BlockBreakEffectView.fadeEnd {
                continue
            } else {
                alpha = 1 - (elapsed - BlockBreakEffectView.fadeStart) / (BlockBreakEffectView.fadeEnd - BlockBreakEffectView.fadeStart)
            }

            // 패널 밖으로 완전히 벗어난 파편은 어차피 클리핑되므로 건너뛴다
            guard cullBounds.contains(CGPoint(x: b.x, y: b.y)) else { continue }

            let size = b.size
            let half = size / 2
            ctx.saveGState()
            ctx.translateBy(x: b.x, y: b.y)
            ctx.rotate(by: b.spin)
            ctx.setAlpha(alpha)

            // 창 톤 색 + 복셀 큐브 느낌의 엣지 쉐이딩
            // (테두리 stroke는 넣지 않는다: 실측 @2x·1980개 기준 stroke 3패스가 12.2ms → 5.7ms로 그리기 비용의 절반을 차지했다)
            ctx.setFillColor(b.color)
            ctx.fill(CGRect(x: -half, y: -half, width: size, height: size))

            // 빛 방향: 위는 밝게, 왼쪽은 어둡게
            ctx.setFillColor(BlockBreakEffectView.highlightColor)
            ctx.fill(CGRect(x: -half + 1, y: half - 5, width: size - 2, height: 4))
            ctx.setFillColor(BlockBreakEffectView.shadeColor)
            ctx.fill(CGRect(x: -half + 1, y: -half + 1, width: 4, height: size - 2))
            ctx.restoreGState()
        }

        // 4) 섬광 (0.16초): 파편 위에 얹는다.
        //    파편이 창을 덮고 있는 동안에는 뒤에 그린 섬광이 가려 보이지 않기 때문이다.
        //    세 원의 반지름이 곧 프레임당 채우는 픽셀 면적이라(면적 ∝ 반지름²) 예전 반지름 760/664/460은
        //    폭발 순간 렉의 주 원인이었다(실측 @2x: 프레임 평균 13.6ms·최악 41ms). 작고 강한 섬광으로 바꿔 1/6로 줄였다.
        guard t < BlockBreakEffectView.flashDuration else { return }
        let f = t / BlockBreakEffectView.flashDuration

        // 부드러운 바깥 광휘
        let glowRadius = 120 + 170 * f
        ctx.setFillColor(NSColor(white: 1, alpha: (1 - f) * 0.20).cgColor)
        ctx.fillEllipse(in: CGRect(x: blast.x - glowRadius, y: blast.y - glowRadius,
                                   width: glowRadius * 2, height: glowRadius * 2))

        // 주황 링
        let ringRadius = 90 + 210 * f
        ctx.setFillColor(NSColor(srgbRed: 1.0, green: 0.60, blue: 0.18, alpha: (1 - f) * 0.55).cgColor)
        ctx.fillEllipse(in: CGRect(x: blast.x - ringRadius, y: blast.y - ringRadius,
                                   width: ringRadius * 2, height: ringRadius * 2))

        // 흰 코어 (맨 위)
        let coreRadius = 60 + 130 * f
        ctx.setFillColor(NSColor(white: 1, alpha: (1 - f) * 0.95).cgColor)
        ctx.fillEllipse(in: CGRect(x: blast.x - coreRadius, y: blast.y - coreRadius,
                                   width: coreRadius * 2, height: coreRadius * 2))
    }
}

// MARK: - 결정적 난수 (연출 재현용)
private struct SplitMix64 {
    private var s: UInt64

    init(seed: UInt64) {
        s = seed
    }

    mutating func next() -> UInt64 {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        a + (CGFloat(next() >> 11) / CGFloat(1 << 53)) * (b - a)
    }
}
