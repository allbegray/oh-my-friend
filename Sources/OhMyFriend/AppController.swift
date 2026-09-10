import AppKit
import CoreGraphics
import SceneKit
import UniformTypeIdentifiers

public final class AppController: NSObject, CharacterViewDelegate, NSMenuDelegate {
    private var window: CharacterWindow!
    private var physics: PhysicsEngine!
    private var behavior = CharacterBehaviorController()
    private var currentSkinType: BuiltinSkinType = .steve
    private var currentCustomSkinName: String?

    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?

    private var gameTimer: Timer?
    private var scanCounter: Int = 0
    private var cachedPlatforms: [Platform] = []
    private var lastUpdateTime: TimeInterval = 0

    // Pickaxe attack (앱 창 부수기)
    private var attackMenuItem: NSMenuItem?
    private var breakOverlays: [BlockBreakOverlayWindow] = []
    private var tntEntityWindow: TNTEntityWindow?
    private var tntPlacementPoint: CGPoint = .zero
    private var isBreakInProgress = false

    // Ladder descent (사다리 타고 창문 내려가기)
    private var ladderMenuItem: NSMenuItem?
    private var ladderOverlay: LadderOverlayWindow?

    public override init() {
        super.init()
    }

    public func start() {
        // 1. Initial Skin
        let skinImage = BuiltinSkinGenerator.makeSkin(type: currentSkinType)
        guard let skin = SkinTexture(image: skinImage) else {
            fatalError("Failed to create default skin")
        }

        // 2. Determine initial position (above Dock or floor)
        let mainScreen = NSScreen.main ?? NSScreen.screens[0]
        let platforms = ScreenEnvironment.shared.scanPlatforms(for: mainScreen)
        self.cachedPlatforms = platforms

        let initialY = mainScreen.visibleFrame.minY + 20
        let initialX = mainScreen.frame.midX
        let initialPos = CGPoint(x: initialX, y: initialY)

        // 3. Physics & Window Setup
        self.physics = PhysicsEngine(initialPosition: initialPos)
        self.window = CharacterWindow(skin: skin)
        self.window.characterView.characterDelegate = self
        self.window.setFeetPosition(x: initialPos.x, y: initialPos.y)
        self.window.orderFrontRegardless()

        // 4. Status Bar Menu Setup
        setupStatusBar()

        // 5. Start 60 FPS Game Loop
        self.lastUpdateTime = ProcessInfo.processInfo.systemUptime
        self.gameTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(gameLoopTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(self.gameTimer!, forMode: .common)
    }

    // MARK: - Game Loop
    @objc private func gameLoopTick() {
        let now = ProcessInfo.processInfo.systemUptime
        var dt = now - lastUpdateTime
        lastUpdateTime = now

        // Clamp dt to avoid huge jumps if app pauses
        if dt > 0.1 { dt = 0.1 }
        if dt <= 0 { dt = 1.0 / 60.0 }

        let screen = ScreenEnvironment.shared.screen(for: physics.position)

        // Periodic Platform Rescan (every ~30 frames = 0.5s)
        scanCounter += 1
        if scanCounter >= 30 {
            scanCounter = 0
            cachedPlatforms = ScreenEnvironment.shared.scanPlatforms(for: screen)
        }

        let cursorPos = NSEvent.mouseLocation

        // 1. Behavior AI Decision
        behavior.update(
            deltaTime: dt,
            physics: physics,
            characterNode: window.characterView.characterNode,
            platforms: cachedPlatforms,
            screen: screen,
            cursorPos: cursorPos
        )

        // 1.5. TNT: 도화선 점멸 동기화
        syncTNT()

        // 1.6. Ladder descent: sync ladder overlay with climb progress
        syncLadderOverlay()

        // 2. Physics Update
        physics.update(
            deltaTime: CGFloat(dt),
            platforms: cachedPlatforms,
            screenFrame: screen.frame
        )

        // 3. 3D Character Node Animation Update
        window.characterView.characterNode.update(deltaTime: CGFloat(dt))

        // 4. Sync Window Position with Feet
        window.setFeetPosition(x: physics.position.x, y: physics.position.y)

        // 5. Update Status Menu Text
        updateStatusMenuItemText()
    }

    private func updateStatusMenuItemText() {
        guard let item = statusMenuItem else { return }

        let desc: String
        switch behavior.state {
        case .idle:
            if let p = physics.currentPlatform {
                desc = "휴식 중 (\(p.title) 위)"
            } else {
                desc = "휴식 중"
            }
        case .lookAround:
            desc = "주변 둘러보는 중 👀"
        case .walk:
            if let p = physics.currentPlatform {
                desc = "산책 중 (\(p.title))"
            } else {
                desc = "걷는 중"
            }
        case .sit:
            if let p = physics.currentPlatform {
                desc = "\(p.title)에 걸터앉아 쉬는 중 🪑"
            } else {
                desc = "걸터앉아 다리 흔들기"
            }
        case .poke(_, let label):
            desc = label.isEmpty ? "툭툭 건드려보기 ⛏️" : "\(label) ⛏️"
        case .wave:
            desc = "반갑게 손 흔드는 중 👋"
        case .sneakDance:
            desc = "마인크래프트 쉬프트 댄스 🕺"
        case .eating:
            desc = "우물우물 사과 먹는 중 🍎"
        case .placeAndMineBlock:
            desc = "블록 캐는 중 ⛏️"
        case .sleep:
            desc = "쿨쿨 낮잠 자는 중... 💤"
        case .backflip:
            desc = "공중제비 도는 중! 🤸‍♂️"
        case .tnt:
            if let remain = behavior.tntFuseRemaining {
                desc = String(format: "🧨 TNT 폭발까지 %.1f초!", remain)
            } else {
                desc = "🧨 TNT 설치하는 중..."
            }
        case .climbDown:
            desc = "🪜 사다리 타고 창문 내려가는 중"
        case .fall:
            desc = "으악! 떨어지는 중! 🪂"
        case .dragged:
            desc = "사용자에게 잡혀 버둥거리는 중 ✋"
        case .landedCrouch:
            desc = "착지! 쿵 💥"
        }

        item.title = "현재 상태: \(desc)"
    }

    // MARK: - CharacterViewDelegate
    public func characterViewDidStartDrag(_ view: CharacterView, at screenPoint: CGPoint) {
        physics.setDragged(at: screenPoint)
    }

    public func characterViewDidDrag(_ view: CharacterView, to screenPoint: CGPoint) {
        physics.setDragged(at: screenPoint)
    }

    public func characterViewDidEndDrag(_ view: CharacterView, throwVelocity: CGPoint) {
        physics.releaseDrag(throwVelocity: throwVelocity)

        // 약하게 내려놓았고 그 자리가 창문 안이면 창문 위에 얹고 사다리 등반을 예약한다.
        // 세게 던진 경우(throwVelocity 큼)는 기존처럼 그대로 날아간다.
        if hypot(throwVelocity.x, throwVelocity.y) <= CharacterBehaviorController.dropSnapSpeedLimit {
            behavior.placeDropOnWindow(physics: physics, platforms: cachedPlatforms)
        }
    }

    public func characterViewDidRequestMenu(_ view: CharacterView, at event: NSEvent) {
        let menu = buildContextMenu()
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    public func characterViewDidLoadSkinFile(_ view: CharacterView, url: URL) {
        loadCustomSkin(from: url)
    }

    public func characterViewDidClick(_ view: CharacterView) {
        behavior.handleCharacterClicked(physics: physics, characterNode: window.characterView.characterNode)
    }

    public func characterViewDidDoubleClick(_ view: CharacterView) {
        behavior.triggerBackflip(physics: physics, characterNode: window.characterView.characterNode)
    }

    // MARK: - NSMenuDelegate
    public func menuNeedsUpdate(_ menu: NSMenu) {
        attackMenuItem?.isEnabled = canStartTNTBreak()
        ladderMenuItem?.isEnabled = canStartLadderDescent()
    }
    // MARK: - Status Bar & Menus
    private func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item

        if let button = item.button {
            button.image = makeMiniSteveIcon()
            button.toolTip = "마인크래프트 데스크톱 친구 (Oh My Friend)"
        }

        item.menu = buildContextMenu()
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        // 1. Status Display
        let status = NSMenuItem(title: "마인크래프트 친구", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        self.statusMenuItem = status

        menu.addItem(NSMenuItem.separator())

        // 2. Skin Selection Submenu
        // 2. Skin Gallery & Selection
        let galleryItem = NSMenuItem(
            title: "🌐 스킨 갤러리 & 다운로더...",
            action: #selector(didSelectOpenSkinGallery),
            keyEquivalent: "g"
        )
        galleryItem.target = self
        menu.addItem(galleryItem)

        let skinMenu = NSMenu()
        for skin in BuiltinSkinType.allCases {
            let item = NSMenuItem(
                title: skin.displayName,
                action: #selector(didSelectBuiltinSkin(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = skin
            if currentCustomSkinName == nil && skin == currentSkinType {
                item.state = .on
            }
            skinMenu.addItem(item)
        }

        if let customName = currentCustomSkinName {
            skinMenu.addItem(NSMenuItem.separator())
            let currentCustomItem = NSMenuItem(
                title: "현재 착용: \(customName)",
                action: nil,
                keyEquivalent: ""
            )
            currentCustomItem.state = .on
            currentCustomItem.isEnabled = false
            skinMenu.addItem(currentCustomItem)
        }

        skinMenu.addItem(NSMenuItem.separator())
        let customSkinItem = NSMenuItem(
            title: "📁 로컬 스킨 파일(PNG) 열기...",
            action: #selector(didSelectOpenCustomSkin),
            keyEquivalent: "o"
        )
        customSkinItem.target = self
        skinMenu.addItem(customSkinItem)

        let skinSubmenuItem = NSMenuItem(title: "👕 기본 스킨 빠른 선택", action: nil, keyEquivalent: "")
        skinSubmenuItem.submenu = skinMenu
        menu.addItem(skinSubmenuItem)

        // 3. Behavior Mode Submenu
        let modeMenu = NSMenu()
        for mode in BehaviorMode.allCases {
            let item = NSMenuItem(
                title: mode.rawValue,
                action: #selector(didSelectBehaviorMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode
            if mode == behavior.mode {
                item.state = .on
            }
            modeMenu.addItem(item)
        }
        let modeSubmenuItem = NSMenuItem(title: "🎭 행동 모드", action: nil, keyEquivalent: "")
        modeSubmenuItem.submenu = modeMenu
        menu.addItem(modeSubmenuItem)

        // 4. Held Item Submenu
        let itemMenu = NSMenu()
        for item in HeldItem.allCases {
            let mItem = NSMenuItem(
                title: item.rawValue,
                action: #selector(didSelectHeldItem(_:)),
                keyEquivalent: ""
            )
            mItem.target = self
            mItem.representedObject = item
            if window.characterView.characterNode.currentHeldItem == item {
                mItem.state = .on
            }
            itemMenu.addItem(mItem)
        }
        let itemSubmenuItem = NSMenuItem(title: "🗡️ 손에 아이템 들기", action: nil, keyEquivalent: "")
        itemSubmenuItem.submenu = itemMenu
        menu.addItem(itemSubmenuItem)

        // 5. Fun Interactions Submenu
        let actMenu = NSMenu()
        let backflipItem = NSMenuItem(title: "🤸‍♂️ 공중제비 (Backflip)", action: #selector(didSelectBackflip), keyEquivalent: "b")
        backflipItem.target = self
        actMenu.addItem(backflipItem)

        let sneakItem = NSMenuItem(title: "🕺 쉬프트 댄스 (Sneak Dance)", action: #selector(didSelectSneakDance), keyEquivalent: "t")
        sneakItem.target = self
        actMenu.addItem(sneakItem)

        let waveItem = NSMenuItem(title: "👋 손 흔들기 (Wave)", action: #selector(didSelectWave), keyEquivalent: "w")
        waveItem.target = self
        actMenu.addItem(waveItem)

        let mineItem = NSMenuItem(title: "⛏️ 블록 설치하고 캐기", action: #selector(didSelectPlaceAndMine), keyEquivalent: "")
        mineItem.target = self
        actMenu.addItem(mineItem)

        let eatItem = NSMenuItem(title: "🍎 사과 냠냠 먹기", action: #selector(didSelectEating), keyEquivalent: "")
        eatItem.target = self
        actMenu.addItem(eatItem)

        let sleepItem = NSMenuItem(title: "💤 지금 낮잠자기 (Sleep)", action: #selector(didSelectSleep), keyEquivalent: "z")
        sleepItem.target = self
        actMenu.addItem(sleepItem)

        let ladderItem = NSMenuItem(title: "🪜 사다리 타고 창문 내려가기 (Ladder Descent)", action: #selector(didSelectLadderDescent), keyEquivalent: "l")
        ladderItem.target = self
        actMenu.addItem(ladderItem)
        self.ladderMenuItem = ladderItem

        let actSubmenuItem = NSMenuItem(title: "✨ 재미있는 모션 실행", action: nil, keyEquivalent: "")
        actSubmenuItem.submenu = actMenu
        menu.addItem(actSubmenuItem)
        // 4. Scale Submenu
        let scaleMenu = NSMenu()
        let scales: [(String, CGFloat)] = [
            ("아주 작게 (50%)", 0.5),
            ("작게 (70%)", 0.7),
            ("약간 작게 (85%)", 0.85),
            ("기본 (100%)", 1.0),
            ("약간 크게 (125%)", 1.25),
            ("크게 (150%)", 1.5),
            ("매우 크게 (175%)", 1.75),
            ("거대하게 (200%)", 2.0),
            ("초거대 (250%)", 2.5)
        ]

        var matchedPreset = false
        for (name, scaleVal) in scales {
            let item = NSMenuItem(
                title: name,
                action: #selector(didSelectScale(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = scaleVal
            if abs(window.currentScale - scaleVal) < 0.02 {
                item.state = .on
                matchedPreset = true
            }
            scaleMenu.addItem(item)
        }

        scaleMenu.addItem(NSMenuItem.separator())

        if !matchedPreset {
            let currentPct = Int(round(window.currentScale * 100))
            let customCurrentItem = NSMenuItem(
                title: "현재 지정: \(currentPct)%",
                action: nil,
                keyEquivalent: ""
            )
            customCurrentItem.state = .on
            customCurrentItem.isEnabled = false
            scaleMenu.addItem(customCurrentItem)
            scaleMenu.addItem(NSMenuItem.separator())
        }

        let customScaleItem = NSMenuItem(
            title: "✏️ 크기 직접 입력 (Custom Size)...",
            action: #selector(didSelectCustomScale),
            keyEquivalent: "s"
        )
        customScaleItem.target = self
        scaleMenu.addItem(customScaleItem)
        let scaleSubmenuItem = NSMenuItem(title: "📏 캐릭터 크기", action: nil, keyEquivalent: "")
        scaleSubmenuItem.submenu = scaleMenu
        menu.addItem(scaleSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Actions
        let jumpItem = NSMenuItem(
            title: "🦘 폴짝 뛰기 (Jump)",
            action: #selector(didSelectJump),
            keyEquivalent: "j"
        )
        jumpItem.target = self
        menu.addItem(jumpItem)

        let resetItem = NSMenuItem(
            title: "🪟 바닥으로 소환 (Reset to Floor)",
            action: #selector(didSelectResetFloor),
            keyEquivalent: "r"
        )
        resetItem.target = self
        menu.addItem(resetItem)

        // Sound SFX Toggle
        let soundItem = NSMenuItem(
            title: "🔊 효과음 (Sound SFX)",
            action: #selector(didToggleSoundSFX(_:)),
            keyEquivalent: ""
        )
        soundItem.target = self
        soundItem.state = SoundAndEffectsManager.shared.isSoundEnabled ? .on : .off
        menu.addItem(soundItem)

        let attackItem = NSMenuItem(
            title: "🧨 TNT로 창 부수기",
            action: #selector(didSelectTNTBreak),
            keyEquivalent: ""
        )
        attackItem.target = self
        attackItem.isEnabled = canStartTNTBreak()
        self.attackMenuItem = attackItem
        menu.addItem(attackItem)
        menu.addItem(NSMenuItem.separator())

        // 6. Quit
        let quitItem = NSMenuItem(
            title: "종료 (Quit)",
            action: #selector(didSelectQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions
    @objc private func didSelectBuiltinSkin(_ sender: NSMenuItem) {
        guard let skinType = sender.representedObject as? BuiltinSkinType else { return }
        self.currentSkinType = skinType
        self.currentCustomSkinName = nil
        let img = BuiltinSkinGenerator.makeSkin(type: skinType)
        if let skin = SkinTexture(image: img) {
            window.characterView.characterNode.applySkin(skin)
        }
        statusItem?.menu = buildContextMenu()
    }

    @objc private func didSelectOpenCustomSkin() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.png]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.message = "마인크래프트 64x64 스킨 PNG 파일을 선택하세요"

        if openPanel.runModal() == .OK, let url = openPanel.url {
            loadCustomSkin(from: url)
        }
    }

    private func loadCustomSkin(from url: URL) {
        if let skin = SkinTexture.load(from: url) {
            applyCustomSkin(skin, name: url.deletingPathExtension().lastPathComponent)
        }
    }
    @objc private func didSelectOpenSkinGallery() {
        SkinGalleryWindowController.shared.show(
            currentScale: window.currentScale,
            onApply: { [weak self] skin, name in
                self?.applyCustomSkin(skin, name: name)
            },
            onScaleChange: { [weak self] newScale in
                self?.window.setScale(newScale)
                self?.statusItem?.menu = self?.buildContextMenu()
            }
        )
    }

    private func applyCustomSkin(_ skin: SkinTexture, name: String) {
        self.currentCustomSkinName = name
        window.characterView.characterNode.applySkin(skin)
        statusItem?.menu = buildContextMenu()
    }

    @objc private func didSelectBehaviorMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? BehaviorMode else { return }
        behavior.mode = mode
        statusItem?.menu = buildContextMenu()
    }

    @objc private func didSelectScale(_ sender: NSMenuItem) {
        guard let scale = sender.representedObject as? CGFloat else { return }
        window.setScale(scale)
        statusItem?.menu = buildContextMenu()
    }

    @objc private func didSelectCustomScale() {
        let alert = NSAlert()
        alert.messageText = "캐릭터 크기 직접 입력"
        alert.informativeText = "원하는 크기 배율을 퍼센트(%) 단위의 숫자로 입력하세요.\n(추천 범위: 30% ~ 300%)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "적용")
        alert.addButton(withTitle: "취소")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        let currentPct = Int(round(window.currentScale * 100))
        input.stringValue = "\(currentPct)"
        input.placeholderString = "예: 120"
        alert.accessoryView = input

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let rawText = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "%", with: "")
            if let num = Double(rawText), num > 0 {
                let clamped = max(20.0, min(400.0, num))
                let scale = CGFloat(clamped / 100.0)
                window.setScale(scale)
                statusItem?.menu = buildContextMenu()
            }
        }
    }

    @objc private func didSelectJump() {
        physics.jump(impulse: 500)
    }

    // MARK: - TNT (앱 창 폭파)
    private func canStartTNTBreak() -> Bool {
        guard !isBreakInProgress,
              let platform = physics?.currentPlatform,
              case .window(_, _, let ownerPid) = platform.kind,
              ownerPid != getpid() else { return false }
        return true
    }

    @objc private func didSelectTNTBreak() {
        guard canStartTNTBreak(),
              let platform = physics.currentPlatform,
              case .window(let windowID, _, let ownerPid) = platform.kind else { return }

        // 1. 대상 앱의 모든 창 수집 (캐릭터가 서 있는 창 포함)
        var windows = ScreenEnvironment.shared.windowsForApp(pid: ownerPid)
        guard !windows.isEmpty else { return }
        if !windows.contains(where: { $0.id == windowID }),
           let targetFrame = ScreenEnvironment.shared.windowCocoaFrame(windowID: windowID) {
            windows.insert((windowID, targetFrame), at: 0)
        }
        if windows.count > 12 {
            // 창이 너무 많으면 12개까지만 (캐릭터가 서 있는 창 우선)
            windows = Array(windows.prefix(12))
            if !windows.contains(where: { $0.id == windowID }),
               let targetFrame = ScreenEnvironment.shared.windowCocoaFrame(windowID: windowID) {
                windows[windows.count - 1] = (windowID, targetFrame)
            }
        }
        let screen = ScreenEnvironment.shared.screen(for: physics.position)

        // 2. 모든 창 위에 폭파 연출 오버레이 생성
        var overlays: [BlockBreakOverlayWindow] = []
        for info in windows {
            let overlay = BlockBreakOverlayWindow(over: info.frame, on: screen)
            overlay.onBreakFinished = { [weak self, weak overlay] in
                guard let self = self else { return }
                self.breakOverlays.removeAll { $0 === overlay }
                if self.breakOverlays.isEmpty {
                    self.isBreakInProgress = false
                }
            }
            overlay.orderFrontRegardless()
            overlays.append(overlay)
        }
        breakOverlays = overlays
        isBreakInProgress = true

        // 3. TNT 설치 → 점화 → 도화선 4초(마인크래프트 표준) → 전 창 동시 폭발
        let started = behavior.startTNTPlacement(
            on: platform,
            fuse: 4.0,
            onPlaced: { [weak self] point in
                // 창 표면에 놓인 TNT 블록을 화면 공간에 표시
                guard let self = self else { return }
                self.tntPlacementPoint = point
                let entity = TNTEntityWindow(at: point)
                entity.orderFrontRegardless()
                self.tntEntityWindow = entity
            },
            completion: { [weak self] endedOn in
                guard let self = self else { return }
                self.tntEntityWindow?.close()
                self.tntEntityWindow = nil

                if endedOn != nil {
                    // 4. 폭발! 대상 앱 종료 + 폭발음 + 모든 창이 동시에 블록 파편으로 비산
                    if let app = NSRunningApplication(processIdentifier: ownerPid) {
                        app.terminate()
                    }
                    SoundAndEffectsManager.shared.play(.explode)
                    for overlay in self.breakOverlays {
                        overlay.explode(at: self.tntPlacementPoint)
                    }
                } else {
                    // 중단(드래그/낙하) → 연출 취소
                    for overlay in self.breakOverlays {
                        overlay.cancel()
                    }
                    self.breakOverlays = []
                    self.isBreakInProgress = false
                }
            }
        )
        if !started {
            for overlay in breakOverlays {
                overlay.cancel()
            }
            breakOverlays = []
            isBreakInProgress = false
        }
    }

    private func syncTNT() {
        guard let progress = behavior.tntProgress else { return }
        for overlay in breakOverlays {
            overlay.showFuse(progress: progress)
        }
        tntEntityWindow?.setFuseProgress(progress)
    }

    /// 등반 스냅샷에 맞춰 사다리 오버레이를 생성/갱신/정리한다
    private func syncLadderOverlay() {
        guard let snapshot = behavior.climbSnapshot else {
            if let overlay = ladderOverlay {
                overlay.retire()
                ladderOverlay = nil
            }
            return
        }

        if let overlay = ladderOverlay {
            overlay.update(ladderRect: snapshot.ladderRect)
        } else {
            let overlay = LadderOverlayWindow(ladderRect: snapshot.ladderRect)
            overlay.update(ladderRect: snapshot.ladderRect)
            overlay.orderFrontRegardless()
            ladderOverlay = overlay
        }
    }

    @objc private func didSelectResetFloor() {
        let mainScreen = NSScreen.main ?? NSScreen.screens[0]
        physics.position = CGPoint(
            x: mainScreen.frame.midX,
            y: mainScreen.visibleFrame.minY + 20
        )
        physics.velocity = .zero
    }

    @objc private func didSelectQuit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Mini Steve Pixel Icon for Status Bar
    private func makeMiniSteveIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()

        // 8x8 Steve face scaled into 16x16 with 1pt border
        let facePixels: [[UInt32]] = [
            // Hair row 1
            [0x452A14, 0x452A14, 0x452A14, 0x452A14, 0x452A14, 0x452A14, 0x452A14, 0x452A14],
            // Hair row 2
            [0x452A14, 0x452A14, 0x452A14, 0x452A14, 0x452A14, 0x452A14, 0x452A14, 0x452A14],
            // Forehead
            [0x452A14, 0xC48E6C, 0xC48E6C, 0xC48E6C, 0xC48E6C, 0xC48E6C, 0xC48E6C, 0x452A14],
            // Eyes
            [0xC48E6C, 0xFFFFFF, 0x3B43A3, 0xC48E6C, 0xC48E6C, 0x3B43A3, 0xFFFFFF, 0xC48E6C],
            // Nose
            [0xC48E6C, 0xC48E6C, 0xC48E6C, 0x9E6E53, 0x9E6E53, 0xC48E6C, 0xC48E6C, 0xC48E6C],
            // Mouth / Beard
            [0xC48E6C, 0xC48E6C, 0x452A14, 0x452A14, 0x452A14, 0x452A14, 0xC48E6C, 0xC48E6C],
            // Chin
            [0xC48E6C, 0x452A14, 0xC48E6C, 0xC48E6C, 0xC48E6C, 0xC48E6C, 0x452A14, 0xC48E6C],
            // Neck
            [0x452A14, 0x452A14, 0xC48E6C, 0xC48E6C, 0xC48E6C, 0xC48E6C, 0x452A14, 0x452A14],
        ]

        let pixelSize: CGFloat = 2.0
        let startX: CGFloat = 1.0
        let startY: CGFloat = 1.0

        for row in 0..<8 {
            for col in 0..<8 {
                let hex = facePixels[7 - row][col]
                let r = CGFloat((hex >> 16) & 0xFF) / 255.0
                let g = CGFloat((hex >> 8) & 0xFF) / 255.0
                let b = CGFloat(hex & 0xFF) / 255.0
                let color = NSColor(red: r, green: g, blue: b, alpha: 1.0)
                color.setFill()

                let rect = NSRect(
                    x: startX + CGFloat(col) * pixelSize,
                    y: startY + CGFloat(row) * pixelSize,
                    width: pixelSize,
                    height: pixelSize
                )
                rect.fill()
            }
        }

        img.unlockFocus()
        img.isTemplate = false
        return img
    }

    // MARK: - New Interaction Action Handlers
    @objc private func didSelectHeldItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? HeldItem else { return }
        window.characterView.characterNode.currentHeldItem = item
        statusItem?.menu = buildContextMenu()
        SoundAndEffectsManager.shared.play(.pop)
    }

    @objc private func didToggleSoundSFX(_ sender: NSMenuItem) {
        SoundAndEffectsManager.shared.isSoundEnabled.toggle()
        sender.state = SoundAndEffectsManager.shared.isSoundEnabled ? .on : .off
        statusItem?.menu = buildContextMenu()
    }

    @objc private func didSelectBackflip() {
        behavior.triggerBackflip(physics: physics, characterNode: window.characterView.characterNode)
    }

    @objc private func didSelectSneakDance() {
        behavior.triggerSneakDance(characterNode: window.characterView.characterNode)
    }

    @objc private func didSelectWave() {
        behavior.triggerWave(characterNode: window.characterView.characterNode)
    }

    @objc private func didSelectPlaceAndMine() {
        behavior.triggerPlaceAndMine(characterNode: window.characterView.characterNode)
    }

    @objc private func didSelectEating() {
        behavior.triggerEating(characterNode: window.characterView.characterNode)
    }

    @objc private func didSelectSleep() {
        behavior.triggerSleep(characterNode: window.characterView.characterNode)
    }

    // MARK: - Ladder Descent (사다리 타고 창문 내려가기)
    private func canStartLadderDescent() -> Bool {
        guard !behavior.isClimbing,
              let platform = physics?.currentPlatform else { return false }
        return CharacterBehaviorController.canDescend(from: platform)
    }

    @objc private func didSelectLadderDescent() {
        guard canStartLadderDescent(), let platform = physics.currentPlatform else { return }
        behavior.startLadderDescent(
            physics: physics,
            characterNode: window.characterView.characterNode,
            from: platform
        )
    }
}
