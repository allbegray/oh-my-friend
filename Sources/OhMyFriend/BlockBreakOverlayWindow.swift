import AppKit

// MARK: - 마인크래프트 블록 파괴 연출 오버레이
// 대상 앱 창 위에 투명 패널을 띄워 ① 창 중앙에서 퍼지는 크랙(5단계) ② 백색 플래시 + 블록 파편 낙하를 그린다.
// 파편 색은 대상 창 실사 스냅샷(화면 기록 권한 있을 때)을 샘플링하고,
// 권한이 없어 스냅샷이 비어 있으면 시스템 모드와 비슷한 톤의 팔레트로 폴백한다.
public final class BlockBreakOverlayWindow: NSPanel {
    private let effectView: BlockBreakEffectView

    /// 파편 연출이 끝난 뒤 호출 (창은 자동으로 닫힘)
    public var onBreakFinished: (() -> Void)?

    /// - Parameters:
    ///   - windowRect: 공격 대상 창의 Cocoa 좌표 프레임
    ///   - screen: 대상 창이 놓인 화면 (파편 낙하 공간 계산용)
    public init(over windowRect: CGRect, on screen: NSScreen) {
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
            windowRectInLocal: CGRect(x: leftRoom, y: bottomRoom, width: windowRect.width, height: windowRect.height)
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

    /// 크랙 단계 표시 (0 = 없음, 1...10 = 갈라짐 진행)
    public func showCrack(stage: Int) {
        effectView.crackStage = min(10, max(0, stage))
    }

    /// 백색 플래시와 함께 창이 블록 파편으로 부서진다
    public func shatter() {
        effectView.beginShatter { [weak self] in
            guard let self = self else { return }
            self.close()
            self.onBreakFinished?()
        }
    }

    /// 연출 중단 (공격이 끊긴 경우)
    public func cancel() {
        effectView.cancelAnimation()
        close()
    }
}

// MARK: - 연출을 직접 그리는 뷰
public final class BlockBreakEffectView: NSView {
    /// 크랙 단계 (1...10). 0이면 아무것도 그리지 않는다.
    public var crackStage: Int = 0 {
        didSet {
            if crackStage != oldValue {
                needsDisplay = true
            }
        }
    }

    private let windowRectInLocal: CGRect

    // 번개형 크랙 트리 (창당 1회 생성, 단계는 노출 길이만 조절)
    private struct CrackBolt {
        var pts: [CGPoint]
        var cum: [CGFloat] // 누적 길이 (pts와 1:1)
        var total: CGFloat
    }
    private struct CrackBranch {
        var bolt: CrackBolt
        var attachAlong: CGFloat // 부모 볼트의 시작점부터 붙는 지점까지 길이
    }
    private var mainBolts: [CrackBolt] = []
    private var branches: [[CrackBranch]] = []
    private var crackBuilt = false

    // 파편 상태
    private struct DebrisBlock {
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var spin: CGFloat
        var spinV: CGFloat
        var color: NSColor
        var delay: CGFloat
    }

    private var debris: [DebrisBlock] = []
    private var burstTime: TimeInterval = 0
    private var timer: Timer?
    private var onShatterDone: (() -> Void)?
    private var hasShattered = false

    private static let gravity: CGFloat = 1500.0
    private static let fadeStart: CGFloat = 1.25
    private static let fadeEnd: CGFloat = 1.85

    public init(windowRectInLocal: CGRect) {
        self.windowRectInLocal = windowRectInLocal
        super.init(frame: NSRect(origin: .zero, size: windowRectInLocal.size))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - 파편 연출

    public func beginShatter(onDone: @escaping () -> Void) {
        guard !hasShattered else { return }
        hasShattered = true
        crackStage = 0
        onShatterDone = onDone
        buildDebris()
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
        hasShattered = false
        crackStage = 0
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

    private func buildDebris() {
        debris.removeAll()
        let win = windowRectInLocal

        // 창 크기에 정확히 맞는 타일 격자 — 남는 가장자리 없이 창 전체를 덮는다
        var targetCell: CGFloat = 22.0
        var cols = max(1, Int((win.width / targetCell).rounded()))
        var rows = max(1, Int((win.height / targetCell).rounded()))
        while cols * rows > 3200 {
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

        let winTopY = win.maxY
        let midX = win.midX
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
                    color: color,
                    delay: 0
                )

                // 위쪽(파괴 시작점)에 가까울수록 먼저 떨어진다.
                // 앞부분 0.06초는 모든 파편이 제자리에 있어 창이 블록 격자로 바뀐 모습이 보인다.
                let depth = (winTopY - centerY) / win.height
                block.delay = 0.06 + depth * 0.22 + rng.range(0, 0.05)

                // 창 중심에서 바깥으로 세게 터진다 (+ 모든 파편에 최소 수평 비산)
                let dx = (centerX - midX) / max(win.width / 2, 1)
                let dy = (centerY - win.midY) / max(win.height / 2, 1)
                let lateralSign: CGFloat = dx >= 0 ? 1 : -1
                block.vx = lateralSign * (abs(dx) * rng.range(220, 560) + rng.range(40, 170)) + rng.range(-50, 50)
                block.vy = abs(dy) * rng.range(140, 300) + rng.range(160, 720)
                // 대기 중에는 축 정렬 상태로 창을 정확히 덮고, 떨어지기 시작하면 회전한다
                block.spin = 0
                debris.append(block)
            }
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
            onShatterDone?()
        } else {
            needsDisplay = true
        }
    }

    // MARK: - 그리기

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        if hasShattered {
            drawDebris(ctx)
        } else if crackStage > 0 {
            drawCracks(ctx)
        }
    }

    // MARK: - 마인크래프트식 크랙: 중앙에서 번개처럼 10단계로 점진 확산

    private func drawCracks(_ ctx: CGContext) {
        let win = windowRectInLocal
        let stage = crackStage // 1...10

        // 번개형 크랙 트리 1회 생성 (중앙에서 창 경계까지)
        if !crackBuilt {
            crackBuilt = true
            buildCrackTree(win)
        }

        let progress = CGFloat(stage) / 10.0 // 0.1...1.0
        // 단계마다 크랙의 "눈에 보이는 끝"이 중앙에서 바깥으로 자란다.
        let eased = pow(progress, 1.35)
        let width: CGFloat = 1.4 + 2.6 * progress
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)

        func strokeAllBolts() {
            for (i, bolt) in mainBolts.enumerated() {
                let reveal = min(1, max(0, eased + boltJitter(i))) // 볼트별 미세 편차
                let reach = reveal * bolt.total
                drawBolt(ctx, bolt, upTo: reach)

                // 곁가지는 부모 크랙이 그 지점까지 자란 뒤에 함께 드러난다
                for branch in branches[i] where branch.attachAlong <= reach {
                    let branchReach = min(1, max(0, eased + boltJitter(i) * 0.5)) * branch.bolt.total
                    drawBolt(ctx, branch.bolt, upTo: branchReach)
                }
            }
        }

        // 1) 하이라이트 패스: 밝은 창 배경에서도 어두운 크랙이 보이도록 테두리
        ctx.setStrokeColor(NSColor(white: 1, alpha: 0.16 + 0.14 * progress).cgColor)
        ctx.setLineWidth(width + 3.5)
        strokeAllBolts()

        // 2) 마인크래프트 destroy 텍스처처럼 어두운 크랙 코어
        ctx.setStrokeColor(NSColor(white: 0.02, alpha: 0.5 + 0.4 * progress).cgColor)
        ctx.setLineWidth(width)
        strokeAllBolts()
    }

    private func boltJitter(_ index: Int) -> CGFloat {
        // 볼트마다 고정된 미세 위상 차 (±0.05) — 전부 동시에 자라지 않게
        let phases: [CGFloat] = [0.04, -0.02, 0.0, -0.04, 0.02, -0.05, 0.03, -0.03, 0.05, -0.01, 0.01, -0.035]
        return phases[index % phases.count]
    }

    private func drawBolt(_ ctx: CGContext, _ bolt: CrackBolt, upTo length: CGFloat) {
        guard bolt.pts.count >= 2, length > 1 else { return }
        var endIndex = 0
        while endIndex + 1 < bolt.cum.count && bolt.cum[endIndex + 1] <= length {
            endIndex += 1
        }
        ctx.beginPath()
        ctx.move(to: bolt.pts[0])
        if endIndex >= 1 {
            for p in bolt.pts[1...endIndex] {
                ctx.addLine(to: p)
            }
        }
        // 마지막 점은 정확히 "지금까지 자란 길이" 위치에 (부드러운 성장)
        if endIndex + 1 < bolt.cum.count, bolt.cum[endIndex] < length {
            let segLen = bolt.cum[endIndex + 1] - bolt.cum[endIndex]
            if segLen > 0.001 {
                let t = (length - bolt.cum[endIndex]) / segLen
                let a = bolt.pts[endIndex]
                let b = bolt.pts[endIndex + 1]
                ctx.addLine(to: CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        ctx.strokePath()
    }

    // MARK: 크랙 트리 생성 (중점 변위법 — 번개 모양)

    private func buildCrackTree(_ win: CGRect) {
        var rng = SplitMix64(seed: 0x9E37_79B9_7F4A_7C15)
        let center = CGPoint(x: win.midX, y: win.midY)

        func boundaryPoint(from c: CGPoint, angle: CGFloat) -> CGPoint {
            let dx = cos(angle)
            let dy = sin(angle)
            var t: CGFloat = .infinity
            if abs(dx) > 1e-6 {
                t = min(t, (dx > 0 ? win.maxX - c.x : c.x - win.minX) / abs(dx))
            }
            if abs(dy) > 1e-6 {
                t = min(t, (dy > 0 ? win.maxY - c.y : c.y - win.minY) / abs(dy))
            }
            return CGPoint(x: c.x + dx * t, y: c.y + dy * t)
        }

        // 1) 주 크랙: 중앙에서 창 경계(사방)까지
        let armCount = 12
        for i in 0..<armCount {
            let angle = CGFloat(i) * 2 * .pi / CGFloat(armCount) + rng.range(-0.12, 0.12)
            let end = boundaryPoint(from: center, angle: angle)
            let dist = hypot(end.x - center.x, end.y - center.y)
            let bolt = makeBolt(from: center, to: end, jag: dist * 0.22, depth: 7, rng: &rng)
            mainBolts.append(bolt)

            // 2) 곁가지: 주 크랙 중간쯤에서 갈라져 옆으로 번짐
            var boltBranches: [CrackBranch] = []
            let branchCount = 2 + (i % 3 == 0 ? 1 : 0)
            for _ in 0..<branchCount {
                let attachFrac = rng.range(0.18, 0.7)
                let attach = attachFrac * bolt.total
                let idx = bolt.cum.firstIndex { $0 >= attach } ?? 0
                let attachPt = bolt.pts[min(idx, bolt.pts.count - 1)]
                // 붙는 지점에서의 진행 방향 기준 좌우로 갈라짐
                let dirIdx = min(idx + 1, bolt.pts.count - 1)
                let segDir = atan2(bolt.pts[dirIdx].y - bolt.pts[max(idx - 1, 0)].y,
                                   bolt.pts[dirIdx].x - bolt.pts[max(idx - 1, 0)].x)
                let spread = rng.range(0.5, 1.4) * (Bool.random() ? 1 : -1)
                let branchEnd = boundaryPoint(from: attachPt, angle: segDir + spread)
                let bDist = hypot(branchEnd.x - attachPt.x, branchEnd.y - attachPt.y)
                let branch = makeBolt(from: attachPt, to: branchEnd, jag: bDist * 0.18, depth: 6, rng: &rng)
                boltBranches.append(CrackBranch(bolt: branch, attachAlong: attach))
            }
            branches.append(boltBranches)
        }
    }

    /// 중점 변위법으로 번개 모양의 꺾인 경로를 만든다
    private func makeBolt(from a: CGPoint, to b: CGPoint, jag: CGFloat, depth: Int, rng: inout SplitMix64) -> CrackBolt {
        var pts: [CGPoint] = [a, b]
        var amplitude = jag
        var d = depth
        while d > 0 {
            var next: [CGPoint] = [pts[0]]
            for i in 0..<(pts.count - 1) {
                let p1 = pts[i]
                let p2 = pts[i + 1]
                let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                let len = max(hypot(p2.x - p1.x, p2.y - p1.y), 0.0001)
                let nx = -(p2.y - p1.y) / len
                let ny = (p2.x - p1.x) / len
                let off = rng.range(-amplitude, amplitude)
                next.append(CGPoint(x: mid.x + nx * off, y: mid.y + ny * off))
                next.append(p2)
            }
            pts = next
            amplitude *= 0.55
            d -= 1
        }
        // 누적 길이 계산
        var cum: [CGFloat] = [0]
        var total: CGFloat = 0
        for i in 1..<pts.count {
            total += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
            cum.append(total)
        }
        return CrackBolt(pts: pts, cum: cum, total: total)
    }

    private func drawDebris(_ ctx: CGContext) {
        let t = CGFloat(burstTime)

        for b in debris {
            let elapsed = t - b.delay

            // 사라지는 구간 알파 처리
            // (아직 대기 중인 파편은 제자리에서 창을 덮은 채 유지 → 부서지기 전 모습과 정확히 일치)
            let alpha: CGFloat
            if elapsed <= BlockBreakEffectView.fadeStart {
                alpha = 1
            } else if elapsed >= BlockBreakEffectView.fadeEnd {
                continue
            } else {
                alpha = 1 - (elapsed - BlockBreakEffectView.fadeStart) / (BlockBreakEffectView.fadeEnd - BlockBreakEffectView.fadeStart)
            }

            let size = b.size
            let half = size / 2
            ctx.saveGState()
            ctx.translateBy(x: b.x, y: b.y)
            ctx.rotate(by: b.spin)

            // 창 실사 색(또는 유사 팔레트) + 복셀 큐브 느낌의 엣지 쉐이딩
            ctx.setFillColor(b.color.withAlphaComponent(alpha).cgColor)
            ctx.fill(CGRect(x: -half, y: -half, width: size, height: size))

            ctx.setLineWidth(1.5)
            ctx.setStrokeColor(NSColor(white: 0, alpha: 0.22 * alpha).cgColor)
            ctx.stroke(CGRect(x: -half + 1, y: -half + 1, width: size - 2, height: size - 2))

            // 빛 방향: 위+왼쪽은 밝게, 아래+오른쪽은 어둡게
            ctx.setFillColor(NSColor(white: 1, alpha: 0.10 * alpha).cgColor)
            ctx.fill(CGRect(x: -half + 1, y: half - 5, width: size - 2, height: 4))
            ctx.setFillColor(NSColor(white: 0, alpha: 0.12 * alpha).cgColor)
            ctx.fill(CGRect(x: -half + 1, y: -half + 1, width: 4, height: size - 2))
            ctx.restoreGState()
        }
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
