import AppKit
import CoreGraphics
import SceneKit
import UniformTypeIdentifiers

public final class AppController: NSObject, CharacterViewDelegate, PetViewDelegate, CreeperViewDelegate, EndermanViewDelegate, SkeletonViewDelegate, NSMenuDelegate {
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

    // Pet Companion (펫 동반자 시스템)
    private var petWindow: PetWindow?
    private var petPhysics: PhysicsEngine?
    private var petBehavior: PetBehaviorController?
    public private(set) var currentPetKind: PetKind? = nil

    // Creeper Entity (크리퍼 출현 & 퇴치)
    private var creeperWindow: CreeperWindow?
    private var creeperPhysics: PhysicsEngine?
    private var creeperBehavior: CreeperBehaviorController?
    private var isCreeperSpawnEnabled: Bool = true
    private var creeperSpawnTimer: TimeInterval = 0
    private var creeperSpawnInterval: TimeInterval = 120.0 // Occasional spawn every ~2 min
    private var playerAttackTimer: TimeInterval = 0

    // Enderman Entity (엔더맨 출현 & 시선 마주침)
    private var endermanWindow: EndermanWindow?
    private var endermanPhysics: PhysicsEngine?
    private var endermanBehavior: EndermanBehaviorController?
    private var isEndermanSpawnEnabled: Bool = true
    private var endermanSpawnTimer: TimeInterval = 0
    private var endermanSpawnInterval: TimeInterval = 150.0

    // Skeleton Entity (스켈레톤 출현 & 활 쏘기)
    private var skeletonWindow: SkeletonWindow?
    private var skeletonPhysics: PhysicsEngine?
    private var skeletonBehavior: SkeletonBehaviorController?
    private var isSkeletonSpawnEnabled: Bool = true
    private var skeletonSpawnTimer: TimeInterval = 0
    private var skeletonSpawnInterval: TimeInterval = 140.0
    private var activeArrows: [ArrowEntityWindow] = []

    // L2. Skin Filter & L3. Glint & L4. Battery
    private var baseSkinTexture: SkinTexture?
    private var currentSkinFilterName: String = "원본 (Original)"
    private var isBatteryHungerEnabled: Bool = true
    private var isBatteryAlertFired: Bool = false
    private var batteryCheckTimer: TimeInterval = 0

    public override init() {
        super.init()
    }

    public func start() {
        // 1. Initial Skin
        let skinImage = BuiltinSkinGenerator.makeSkin(type: currentSkinType)
        guard let skin = SkinTexture(image: skinImage) else {
            fatalError("Failed to create default skin")
        }
        self.baseSkinTexture = skin

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
            screen: screen
        )

        // 3. 3D Character Node Animation Update
        window.characterView.characterNode.update(deltaTime: CGFloat(dt))

        // 4. Sync Window Position with Feet
        window.setFeetPosition(x: physics.position.x, y: physics.position.y)


        // 4.5. Update Pet Companion
        if let pw = petWindow, let pPhys = petPhysics, let pBehav = petBehavior {
            let playerDir = window.characterView.characterNode.modelRoot.eulerAngles.y
            let playerSitting = window.characterView.characterNode.isSitting
            let playerSleeping = window.characterView.characterNode.isSleeping
            pBehav.update(
                deltaTime: CGFloat(dt),
                petPhysics: pPhys,
                petNode: pw.petView.petNode,
                playerPos: physics.position,
                playerIsSitting: playerSitting,
                playerIsSleeping: playerSleeping,
                playerDirection: playerDir,
                screen: screen,
                platforms: cachedPlatforms
            )
            pPhys.update(deltaTime: CGFloat(dt), platforms: cachedPlatforms, screen: screen)
            pw.petView.petNode.update(deltaTime: CGFloat(dt))
            pw.setFeetPosition(x: pPhys.position.x, y: pPhys.position.y)
        }

        // 4.6. Update Creeper Entity
        if let cw = creeperWindow, let cPhys = creeperPhysics, let cBehav = creeperBehavior {
            let catPos: CGPoint?
            if currentPetKind == .cat, let pPhys = petPhysics {
                catPos = pPhys.position
            } else {
                catPos = nil
            }

            cBehav.update(
                deltaTime: CGFloat(dt),
                creeperPhysics: cPhys,
                creeperNode: cw.creeperView.creeperNode,
                playerPos: physics.position,
                catPos: catPos,
                onExplode: { [weak self] blastPos in
                    self?.handleCreeperExploded(at: blastPos)
                },
                onDefeated: { [weak self] in
                    let currentWeapon = self?.window.characterView.characterNode.currentHeldItem ?? .none
                    self?.handleCreeperDefeated(with: currentWeapon)
                }
            )
            cPhys.update(deltaTime: CGFloat(dt), platforms: cachedPlatforms, screen: screen)
            cw.creeperView.creeperNode.update(deltaTime: CGFloat(dt))
            cw.setFeetPosition(x: cPhys.position.x, y: cPhys.position.y)

            // Auto-attack if player has weapon equipped and Creeper gets dangerously close (< 100pt)
            let dist = hypot(cPhys.position.x - physics.position.x, cPhys.position.y - physics.position.y)
            if dist < 100.0 && !cBehav.isDespawned && playerAttackTimer <= 0 {
                attackCreeperWithCurrentWeapon()
            }
        }

        // Player attack animation timer
        if playerAttackTimer > 0 {
            playerAttackTimer -= dt
            if playerAttackTimer <= 0 {
                window.characterView.characterNode.isAttackingWeapon = false
            }
        }

        // Autonomous Creeper Spawning
        if isCreeperSpawnEnabled && creeperWindow == nil {
            creeperSpawnTimer += dt
            if creeperSpawnTimer >= creeperSpawnInterval {
                creeperSpawnTimer = 0
                spawnCreeper()
            }
        }

        // L4. Battery Hunger Check (every ~5.0s)
        if isBatteryHungerEnabled {
            batteryCheckTimer += dt
            if batteryCheckTimer >= 5.0 {
                batteryCheckTimer = 0
                let bInfo = BatteryStatusMonitor.shared.getBatteryInfo()
                if bInfo.hasBattery {
                    if !bInfo.isCharging && bInfo.percent <= 20 {
                        if !isBatteryAlertFired {
                            isBatteryAlertFired = true
                            window.characterView.characterNode.showOverheadEmoji("🍗 배고파... 꼬르륵 (배터리 \(bInfo.percent)%)", duration: 3.0)
                            SoundAndEffectsManager.shared.play(.alert)
                        }
                    } else if bInfo.isCharging && isBatteryAlertFired {
                        isBatteryAlertFired = false
                        window.characterView.characterNode.showOverheadEmoji("⚡ 충전기 연결! 힘이 솟는다!", duration: 2.5)
                        SoundAndEffectsManager.shared.play(.heart)
                    }
                }
            }
        }

        // 4.7. Update Enderman Entity
        if let ew = endermanWindow, let ePhys = endermanPhysics, let eBehav = endermanBehavior {
            eBehav.update(
                deltaTime: CGFloat(dt),
                endermanPhysics: ePhys,
                endermanNode: ew.endermanView.endermanNode,
                playerPos: physics.position,
                cursorPos: cursorPos,
                screen: screen,
                onDefeated: { [weak self] in
                    self?.handleEndermanDefeated()
                }
            )
            ePhys.update(deltaTime: CGFloat(dt), platforms: cachedPlatforms, screen: screen)
            ew.endermanView.endermanNode.update(deltaTime: CGFloat(dt))
            ew.setFeetPosition(x: ePhys.position.x, y: ePhys.position.y)

            // Auto-attack if player has weapon and Enderman charges dangerously close
            let dist = hypot(ePhys.position.x - physics.position.x, ePhys.position.y - physics.position.y)
            if dist < 110.0 && !eBehav.isDespawned && eBehav.isEnraged && playerAttackTimer <= 0 {
                attackEndermanWithCurrentWeapon()
            }
        }

        // 4.8. Update Skeleton Entity
        if let sw = skeletonWindow, let sPhys = skeletonPhysics, let sBehav = skeletonBehavior {
            sBehav.update(
                deltaTime: CGFloat(dt),
                skeletonPhysics: sPhys,
                skeletonNode: sw.skeletonView.skeletonNode,
                playerPos: physics.position,
                platforms: cachedPlatforms,
                screen: screen,
                onShootArrow: { [weak self] startPos, targetPos in
                    self?.launchArrowFromSkeleton(from: startPos, to: targetPos)
                },
                onDefeated: { [weak self] in
                    self?.handleSkeletonDefeated()
                }
            )
            sPhys.update(deltaTime: CGFloat(dt), platforms: cachedPlatforms, screen: screen)
            sw.skeletonView.skeletonNode.update(deltaTime: CGFloat(dt))
            sw.setFeetPosition(x: sPhys.position.x, y: sPhys.position.y)

            // Auto-attack if player has weapon and Skeleton is within 100pt
            let dist = hypot(sPhys.position.x - physics.position.x, sPhys.position.y - physics.position.y)
            if dist < 100.0 && !sBehav.isDespawned && playerAttackTimer <= 0 {
                attackSkeletonWithCurrentWeapon()
            }
        }

        // Autonomous Skeleton Spawning
        if isSkeletonSpawnEnabled && skeletonWindow == nil {
            skeletonSpawnTimer += dt
            if skeletonSpawnTimer >= skeletonSpawnInterval {
                skeletonSpawnTimer = 0
                spawnSkeleton()
            }
        }

        // Autonomous Enderman Spawning
        if isEndermanSpawnEnabled && endermanWindow == nil {
            endermanSpawnTimer += dt
            if endermanSpawnTimer >= endermanSpawnInterval {
                endermanSpawnTimer = 0
                spawnEnderman()
            }
        }
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
                if p.kind == .menuBar {
                    desc = "상단 메뉴바에 걸터앉아 쉬는 중 🪑"
                } else {
                    desc = "\(p.title)에 걸터앉아 쉬는 중 🪑"
                }
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
        case .cheer(let wpm, _, _):
            desc = "코딩 신나게 응원 중! 🔥 (WPM: \(Int(wpm)))"
        case .nag:
            desc = "쌓인 알림 안 읽는다고 구박하는 중! 💢"
        case .tnt:
            if let remain = behavior.tntFuseRemaining {
                desc = String(format: "🧨 TNT 폭발까지 %.1f초!", remain)
            } else {
                desc = "🧨 TNT 설치하는 중..."
            }
        case .squash:
            desc = "창을 압축해서 Dock으로 치우는 중! 🗜️"
        case .fishing:
            desc = "물가에 낚싯대 드리우고 낚시 중 🎣"
        case .climb(_, _, let isUp):
            desc = isUp ? "🪜 사다리 타고 창문 올라가는 중" : "🪜 사다리 타고 창문 내려가는 중"
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

        // 약하게 놓았고 그 자리가 창문 안이면, 놓인 자리에서 그 창문 위쪽 끝까지 사다리를 걸고 올라간다.
        // 세게 던진 경우(throwVelocity 큼)는 기존처럼 그대로 날아간다.
        if hypot(throwVelocity.x, throwVelocity.y) <= CharacterBehaviorController.dropSnapSpeedLimit {
            behavior.climbUpFromDrop(
                physics: physics,
                characterNode: window.characterView.characterNode,
                platforms: cachedPlatforms
            )
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
        if window.characterView.characterNode.isGliding {
            let facingDir = window.characterView.characterNode.modelRoot.eulerAngles.y
            physics.fireworkRocketBoost(facingDir: facingDir)
            window.characterView.characterNode.showOverheadEmoji("🚀 슈우웅!", duration: 1.5)
            SoundAndEffectsManager.shared.play(.ignite)
            return
        }
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

        // L2. Skin Color / Hue Filter Submenu
        let filterMenu = NSMenu()
        let filters: [(name: String, hue: CGFloat, sat: CGFloat, bri: CGFloat)] = [
            ("원본 (Original)", 0.0, 1.0, 0.0),
            ("🌈 색조 회전 +90°", CGFloat.pi / 2.0, 1.0, 0.0),
            ("🌈 색조 반전 +180°", CGFloat.pi, 1.0, 0.0),
            ("🌈 네온 틴트 +270°", CGFloat.pi * 1.5, 1.3, 0.04),
            ("⬛ 흑백 레트로 (Grayscale)", 0.0, 0.0, 0.0),
            ("✨ 선명한 비비드 (Vivid)", 0.0, 1.8, 0.02)
        ]
        for f in filters {
            let fItem = NSMenuItem(
                title: f.name,
                action: #selector(didSelectSkinFilter(_:)),
                keyEquivalent: ""
            )
            fItem.target = self
            fItem.representedObject = f.name
            if currentSkinFilterName == f.name {
                fItem.state = .on
            }
            filterMenu.addItem(fItem)
        }
        let filterSubmenuItem = NSMenuItem(title: "🎨 스킨 색조/필터 조절", action: nil, keyEquivalent: "")
        filterSubmenuItem.submenu = filterMenu
        menu.addItem(filterSubmenuItem)

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

        // Off-hand Shield Toggle
        let shieldItem = NSMenuItem(
            title: "🛡️ 왼손에 방패 착용 (Off-hand Shield)",
            action: #selector(didToggleShield(_:)),
            keyEquivalent: ""
        )
        shieldItem.target = self
        shieldItem.state = window.characterView.characterNode.isShieldEquipped ? .on : .off
        menu.addItem(shieldItem)


        // Elytra Toggle
        let elytraItem = NSMenuItem(
            title: "🪽 겉날개 착용 (Equip Elytra)",
            action: #selector(didToggleElytra(_:)),
            keyEquivalent: ""
        )
        elytraItem.target = self
        elytraItem.state = window.characterView.characterNode.isElytraEquipped ? .on : .off
        menu.addItem(elytraItem)
        // Pet Companion Submenu
        let petMenu = NSMenu()
        for kind in PetKind.allCases {
            let item = NSMenuItem(
                title: kind.displayName,
                action: #selector(didSelectPetKind(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = kind
            if currentPetKind == kind {
                item.state = .on
            }
            petMenu.addItem(item)
        }
        petMenu.addItem(NSMenuItem.separator())
        let feedItem = NSMenuItem(
            title: "🦴 펫에게 간식/먹이 주기 (Feed)",
            action: #selector(didSelectFeedPet),
            keyEquivalent: ""
        )
        feedItem.target = self
        feedItem.isEnabled = (currentPetKind != nil)
        petMenu.addItem(feedItem)

        let dismissItem = NSMenuItem(
            title: "❌ 펫 소환 해제 (Dismiss)",
            action: #selector(didSelectDismissPet),
            keyEquivalent: ""
        )
        dismissItem.target = self
        if currentPetKind == nil {
            dismissItem.state = .on
        }
        petMenu.addItem(dismissItem)

        let petSubmenuItem = NSMenuItem(title: "🐾 펫 동반자 (Pet Companion)", action: nil, keyEquivalent: "")
        petSubmenuItem.submenu = petMenu
        menu.addItem(petSubmenuItem)

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

        let skelItem = NSMenuItem(title: "🏹 스켈레톤 소환 (Spawn Skeleton)", action: #selector(didSelectSpawnSkeleton), keyEquivalent: "")
        skelItem.target = self
        actMenu.addItem(skelItem)

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


        let menuBarSitItem = NSMenuItem(title: "🪑 상단 메뉴바에 걸터앉기", action: #selector(didSelectSitOnMenuBar), keyEquivalent: "m")
        menuBarSitItem.target = self
        actMenu.addItem(menuBarSitItem)

        let creeperItem = NSMenuItem(title: "💥 크리퍼 소환 (Spawn Creeper)", action: #selector(didSelectSpawnCreeper), keyEquivalent: "k")
        creeperItem.target = self
        actMenu.addItem(creeperItem)


        let endermanItem = NSMenuItem(title: "👁️ 엔더맨 소환 (Spawn Enderman)", action: #selector(didSelectSpawnEnderman), keyEquivalent: "e")
        endermanItem.target = self
        actMenu.addItem(endermanItem)
        let cheerItem = NSMenuItem(title: "🎉 코딩 신나게 응원하기 (Cheer)", action: #selector(didSelectCheer), keyEquivalent: "c")
        cheerItem.target = self
        actMenu.addItem(cheerItem)

        let nagItem = NSMenuItem(title: "💢 알림 안 읽는다고 구박하기 (Nag)", action: #selector(didSelectNag), keyEquivalent: "n")
        nagItem.target = self
        actMenu.addItem(nagItem)

        let fishItem = NSMenuItem(title: "🎣 모서리 낚시하기 (Go Fishing)", action: #selector(didSelectFishing), keyEquivalent: "f")
        fishItem.target = self
        actMenu.addItem(fishItem)
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


        // Skeleton Spawning Toggle
        let skelToggleItem = NSMenuItem(
            title: "👾 가끔 스켈레톤 출현 모드",
            action: #selector(didToggleSkeletonSpawn(_:)),
            keyEquivalent: ""
        )
        skelToggleItem.target = self
        skelToggleItem.state = isSkeletonSpawnEnabled ? .on : .off
        menu.addItem(skelToggleItem)
        // Typing Cheer Toggle
        let typingCheerItem = NSMenuItem(
            title: "⌨️ 타이핑 응원 모드 (WPM 감지)",
            action: #selector(didToggleTypingCheer(_:)),
            keyEquivalent: ""
        )
        typingCheerItem.target = self
        typingCheerItem.state = TypingActivityMonitor.shared.isEnabled ? .on : .off
        menu.addItem(typingCheerItem)

        if !TypingActivityMonitor.shared.isAccessibilityTrusted {
            let permItem = NSMenuItem(
                title: "  ℹ️ 타 앱 타이핑 감지: 손쉬운 사용 권한 필요",
                action: #selector(didSelectOpenAccessibilitySettings),
                keyEquivalent: ""
            )
            permItem.target = self
            menu.addItem(permItem)
        }

        // Notification Nag Toggle
        let nagToggleItem = NSMenuItem(
            title: "🔔 쌓인 알림 잔소리/구박 모드",
            action: #selector(didToggleNotificationNag(_:)),
            keyEquivalent: ""
        )
        nagToggleItem.target = self

        // L3. Enchantment Glint Toggle
        let glintItem = NSMenuItem(
            title: "🔮 무기 인챈트 광택 (Enchantment Glint)",
            action: #selector(didToggleEnchantmentGlint(_:)),
            keyEquivalent: ""
        )
        glintItem.target = self
        glintItem.state = window.characterView.characterNode.isEnchantedGlintEnabled ? .on : .off
        menu.addItem(glintItem)

        // L4. Battery Hunger Toggle
        let batteryToggleItem = NSMenuItem(
            title: "🍗 맥북 배터리 연동 허기 모드",
            action: #selector(didToggleBatteryHunger(_:)),
            keyEquivalent: ""
        )
        batteryToggleItem.target = self
        batteryToggleItem.state = isBatteryHungerEnabled ? .on : .off
        menu.addItem(batteryToggleItem)
        nagToggleItem.state = NotificationCenterMonitor.shared.isEnabled ? .on : .off
        menu.addItem(nagToggleItem)

        // Creeper Spawning Toggle
        let creeperToggleItem = NSMenuItem(
            title: "👾 가끔 크리퍼 출현 모드",
            action: #selector(didToggleCreeperSpawn(_:)),
            keyEquivalent: ""
        )

        // Enderman Spawning Toggle
        let endermanToggleItem = NSMenuItem(
            title: "👾 가끔 엔더맨 출현 모드",
            action: #selector(didToggleEndermanSpawn(_:)),
            keyEquivalent: ""
        )
        endermanToggleItem.target = self
        endermanToggleItem.state = isEndermanSpawnEnabled ? .on : .off
        menu.addItem(endermanToggleItem)
        creeperToggleItem.target = self
        creeperToggleItem.state = isCreeperSpawnEnabled ? .on : .off
        menu.addItem(creeperToggleItem)


        let squashItem = NSMenuItem(
            title: "🗜️ 이 창 압축해서 Dock으로 치우기",
            action: #selector(didSelectSquashMinimize),
            keyEquivalent: ""
        )
        squashItem.target = self
        squashItem.isEnabled = canStartSquashMinimize()
        menu.addItem(squashItem)
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
            self.baseSkinTexture = skin
            self.currentSkinFilterName = "원본 (Original)"
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
        self.baseSkinTexture = skin
        self.currentSkinFilterName = "원본 (Original)"
        window.characterView.characterNode.applySkin(skin)
        statusItem?.menu = buildContextMenu()
    }


    // MARK: - Skin Filter Action
    @objc private func didSelectSkinFilter(_ sender: NSMenuItem) {
        guard let filterName = sender.representedObject as? String else { return }
        guard let base = baseSkinTexture else { return }
        self.currentSkinFilterName = filterName

        var adjusted: SkinTexture?
        switch filterName {
        case "🌈 색조 회전 +90°":
            adjusted = base.withColorAdjustment(hueAngle: CGFloat.pi / 2.0)
        case "🌈 색조 반전 +180°":
            adjusted = base.withColorAdjustment(hueAngle: CGFloat.pi)
        case "🌈 네온 틴트 +270°":
            adjusted = base.withColorAdjustment(hueAngle: CGFloat.pi * 1.5, saturation: 1.3, brightness: 0.04)
        case "⬛ 흑백 레트로 (Grayscale)":
            adjusted = base.withColorAdjustment(saturation: 0.0)
        case "✨ 선명한 비비드 (Vivid)":
            adjusted = base.withColorAdjustment(saturation: 1.8, brightness: 0.02)
        default:
            adjusted = base
        }

        if let finalSkin = adjusted {
            window.characterView.characterNode.applySkin(finalSkin)
            SoundAndEffectsManager.shared.play(.pop)
        }
        statusItem?.menu = buildContextMenu()
    }

    @objc private func didToggleEnchantmentGlint(_ sender: NSMenuItem) {
        window.characterView.characterNode.isEnchantedGlintEnabled.toggle()
        sender.state = window.characterView.characterNode.isEnchantedGlintEnabled ? .on : .off
        statusItem?.menu = buildContextMenu()
        SoundAndEffectsManager.shared.play(.heart)
    }

    @objc private func didToggleBatteryHunger(_ sender: NSMenuItem) {
        isBatteryHungerEnabled.toggle()
        sender.state = isBatteryHungerEnabled ? .on : .off
        statusItem?.menu = buildContextMenu()
        SoundAndEffectsManager.shared.play(.pop)
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
        //    동시에 폭발하는 창들이 파편 예산을 나눠 쓴다 (파편 수 = 프레임당 그리기 비용)
        let debrisShare = max(BlockBreakOverlayWindow.minimumDebrisPerWindow,
                              BlockBreakOverlayWindow.debrisBudgetTotal / max(1, windows.count))
        var overlays: [BlockBreakOverlayWindow] = []
        for info in windows {
            let overlay = BlockBreakOverlayWindow(over: info.frame, on: screen, debrisBudget: debrisShare)
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

    @objc private func didSelectSitOnMenuBar() {
        behavior.triggerSitOnMenuBar(physics: physics, characterNode: window.characterView.characterNode)
    }

    @objc private func didSelectCheer() {
        behavior.triggerCheer(characterNode: window.characterView.characterNode)
    }

    @objc private func didToggleTypingCheer(_ sender: NSMenuItem) {
        TypingActivityMonitor.shared.isEnabled.toggle()
        sender.state = TypingActivityMonitor.shared.isEnabled ? .on : .off
        statusItem?.menu = buildContextMenu()
    }

    @objc private func didSelectOpenAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func didSelectNag() {
        behavior.triggerNag(characterNode: window.characterView.characterNode)
    }

    @objc private func didToggleNotificationNag(_ sender: NSMenuItem) {
        NotificationCenterMonitor.shared.isEnabled.toggle()
        sender.state = NotificationCenterMonitor.shared.isEnabled ? .on : .off
        statusItem?.menu = buildContextMenu()
    }


    // MARK: - Pet Companion (펫 동반자 시스템)
    public func summonPet(kind: PetKind) {
        self.currentPetKind = kind
        if petWindow == nil {
            let pw = PetWindow(kind: kind)
            pw.petView.petDelegate = self
            self.petWindow = pw
            let spawnX = physics.position.x - 70
            let pPhys = PhysicsEngine(initialPosition: CGPoint(x: spawnX, y: physics.position.y))
            self.petPhysics = pPhys
            self.petBehavior = PetBehaviorController()
            pw.setFeetPosition(x: spawnX, y: physics.position.y)
            pw.orderFrontRegardless()
        } else {
            petWindow?.petView.petNode.setKind(kind)
        }
        petWindow?.petView.petNode.showOverheadEmoji("✨", duration: 1.8)
        SoundAndEffectsManager.shared.play(.heart)
    }

    public func dismissPet() {
        self.currentPetKind = nil
        petWindow?.orderOut(nil)
        petWindow = nil
        petPhysics = nil
        petBehavior = nil
        SoundAndEffectsManager.shared.play(.pop)
    }

    @objc private func didSelectPetKind(_ sender: NSMenuItem) {
        guard let kind = sender.representedObject as? PetKind else { return }
        summonPet(kind: kind)
        statusItem?.menu = buildContextMenu()
    }

    @objc private func didSelectDismissPet() {
        dismissPet()
        statusItem?.menu = buildContextMenu()
    }

    @objc private func didSelectFeedPet() {
        guard let pw = petWindow else { return }
        pw.petView.petNode.feed()
        window.characterView.characterNode.showOverheadEmoji("🦴 냠냠 맛있게 먹어!", duration: 2.0)
    }

    // MARK: - PetViewDelegate
    public func petViewDidClick(_ view: PetView) {
        if window.characterView.characterNode.currentHeldItem == .bone || view.petNode.wolfHealth < 0.95 {
            view.petNode.feed()
            window.characterView.characterNode.showOverheadEmoji("🦴 냠냠!", duration: 1.8)
            return
        }
        petBehavior?.handlePetClicked(petNode: view.petNode)
    }

    public func petViewDidStartDrag(_ view: PetView, at screenPoint: CGPoint) {
        petPhysics?.setDragged(at: screenPoint)
    }

    public func petViewDidDrag(_ view: PetView, to screenPoint: CGPoint) {
        petPhysics?.setDragged(at: screenPoint)
    }

    public func petViewDidEndDrag(_ view: PetView, throwVelocity: CGPoint) {
        petPhysics?.releaseDrag(throwVelocity: throwVelocity)
    }

    // MARK: - Creeper Combat & Spawning (크리퍼 전투 및 소환)
    public func spawnCreeper() {
        guard creeperWindow == nil else { return }
        let cw = CreeperWindow()
        cw.creeperView.creeperDelegate = self
        self.creeperWindow = cw

        // Spawn on the current platform or ~260pt away
        let spawnDir: CGFloat = Bool.random() ? 1.0 : -1.0
        let spawnX = physics.position.x + (spawnDir * 260.0)
        let cPhys = PhysicsEngine(initialPosition: CGPoint(x: spawnX, y: physics.position.y))
        self.creeperPhysics = cPhys
        self.creeperBehavior = CreeperBehaviorController()

        cw.setFeetPosition(x: spawnX, y: physics.position.y)
        cw.orderFrontRegardless()
        cw.creeperView.creeperNode.showOverheadEmoji("👾 나타났다!", duration: 1.8)
        SoundAndEffectsManager.shared.play(.alert)

        // 플레이어 살기 감지 대사 출력
        let warningQuotes = [
            "등골이 서늘한데...? 살기가 느껴져! 😨",
            "불길한 기운이 감돈다... 크리퍼인가?! ⚠️",
            "뒤에서 바스락거리는 소리가 들렸어! 💢",
            "크리퍼 냄새가 나는데... 어디지?! 👃",
            "잠깐... 불길한 시선이 느껴져! 👀",
            "살기 감지! 무기 들 준비 해! ⚔️"
        ]
        let quote = warningQuotes.randomElement() ?? warningQuotes[0]
        window.characterView.characterNode.showOverheadEmoji(quote, duration: 3.0)

        // 소환된 펫이 있다면 펫도 위협을 감지하고 반응!
        if let petNode = petWindow?.petView.petNode {
            let petReaction: String
            switch petNode.kind {
            case .wolf: petReaction = "으르렁...! 🐺"
            case .cat: petReaction = "하악질! 😾"
            case .parrot: petReaction = "비상! 비상! 🦜"
            case .pig: petReaction = "꿀꿀?! 🐷"
            }
            petNode.showOverheadEmoji(petReaction, duration: 2.5)
        }
    }

    public func despawnCreeper() {
        creeperWindow?.orderOut(nil)
        creeperWindow = nil
        creeperPhysics = nil
        creeperBehavior = nil
    }

    public func attackCreeperWithCurrentWeapon() {
        guard let cw = creeperWindow,
              let cPhys = creeperPhysics,
              let cBehav = creeperBehavior,
              !cBehav.isDespawned else { return }

        // Face towards Creeper
        let dx = cPhys.position.x - physics.position.x
        window.characterView.characterNode.modelRoot.eulerAngles.y = dx >= 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)

        // Trigger attack animation on player
        window.characterView.characterNode.isAttackingWeapon = true
        playerAttackTimer = 0.35

        let weapon = window.characterView.characterNode.currentHeldItem
        let damage: Int
        let playerEmoji: String

        switch weapon {
        case .diamondSword:
            damage = 3 // 1-hit kill!
            playerEmoji = "⚔️ 슬래시!"
        case .diamondPickaxe:
            damage = 2
            playerEmoji = "⛏️ 강타!"
        case .torch:
            damage = 1
            playerEmoji = "🕯️ 횃불 지지기!"
        case .goldenApple:
            damage = 1
            playerEmoji = "🍎 사과 쿵!"
        case .fishingRod:
            damage = 1
            playerEmoji = "🎣 낚싯줄 찌르기!"
        case .bone:
            damage = 1
            playerEmoji = "🦴 뼈다귀 어택!"
        case .none:
            damage = 1
            playerEmoji = "👊 펀치!"
        }

        window.characterView.characterNode.showOverheadEmoji(playerEmoji, duration: 1.2)

        cBehav.applyDamage(
            damage,
            fromPlayerAt: physics.position,
            weapon: weapon,
            creeperPhysics: cPhys,
            creeperNode: cw.creeperView.creeperNode,
            onDefeated: { [weak self] in
                self?.handleCreeperDefeated(with: weapon)
            }
        )
    }

    private func handleCreeperExploded(at blastPos: CGPoint) {
        let charNode = window.characterView.characterNode
        let isGuarding = charNode.isShieldEquipped && (charNode.isSneaking || charNode.isGuarding)

        if isGuarding {
            // 원작 고증: 방패로 가드 시 100% 폭발 피해 및 넉백 완벽 방어!
            charNode.showOverheadEmoji("🛡️ 챙-! 완벽 방어!", duration: 2.5)
            SoundAndEffectsManager.shared.play(.pop)
        } else {
            let dx = physics.position.x - blastPos.x
            let blastDir: CGFloat = dx >= 0 ? 1.0 : -1.0
            physics.launch(vx: blastDir * 550.0, vy: 420.0)
            charNode.showOverheadEmoji("💥 으악!", duration: 2.0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.despawnCreeper()
        }
    }

    private func handleCreeperDefeated(with weapon: HeldItem) {
        let victoryQuote: String
        switch weapon {
        case .diamondSword:
            let quotes = [
                "칼날 끝에 자비란 없다! ⚔️",
                "크리퍼 따위, 내 검엔 한 방이지! 🗡️",
                "터지기 전에 베었다! 완벽한 칼각! ✨",
                "화약 득템! 폭탄 만들러 가볼까? 💥"
            ]

            victoryQuote = quotes.randomElement() ?? quotes[0]
        case .diamondPickaxe:
            let quotes = [
                "단단한 놈은 곡괭이로 캐는 법! ⛏️",
                "광물인 줄 알고 캤더니 크리퍼였네? 💎",
                "곡괭이 맛이 어떠냐! ⛏️"
            ]
            victoryQuote = quotes.randomElement() ?? quotes[0]
        case .torch:
            let quotes = [
                "불장난은 위험하다고 했잖아? 🔥",
                "횃불 하나로 제압 완료! 🕯️",
                "어둠 속에 숨을 생각 마라! ⚡"
            ]
            victoryQuote = quotes.randomElement() ?? quotes[0]
        default:
            let quotes = [
                "이 구역의 평화는 내가 지킨다! 🛡️",
                "어딜 감히 내 데스크톱에 얼씬거려! 👊",
                "휴, 터지기 전에 컷! 나 좀 멋진 듯? 😎"
            ]
            victoryQuote = quotes.randomElement() ?? quotes[0]
        }

        // 승리의 포즈 및 멋진 대사 출력
        window.characterView.characterNode.showOverheadEmoji(victoryQuote, duration: 3.2)
        SoundAndEffectsManager.shared.play(.heart)

        // 승리의 기쁨 점프
        physics.jump(impulse: 340)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.despawnCreeper()
        }
    }

    @objc private func didSelectSpawnCreeper() {
        spawnCreeper()
    }

    @objc private func didToggleCreeperSpawn(_ sender: NSMenuItem) {
        isCreeperSpawnEnabled.toggle()
        sender.state = isCreeperSpawnEnabled ? .on : .off
        statusItem?.menu = buildContextMenu()
    }

    @objc private func didToggleElytra(_ sender: NSMenuItem) {
        window.characterView.characterNode.isElytraEquipped.toggle()
        sender.state = window.characterView.characterNode.isElytraEquipped ? .on : .off
        statusItem?.menu = buildContextMenu()
        SoundAndEffectsManager.shared.play(.pop)
    }

    // MARK: - CreeperViewDelegate
    public func creeperViewDidClick(_ view: CreeperView) {
        attackCreeperWithCurrentWeapon()
    }

    public func creeperViewDidStartDrag(_ view: CreeperView, at screenPoint: CGPoint) {
        creeperPhysics?.setDragged(at: screenPoint)
    }

    public func creeperViewDidDrag(_ view: CreeperView, to screenPoint: CGPoint) {
        creeperPhysics?.setDragged(at: screenPoint)
    }

    public func creeperViewDidEndDrag(_ view: CreeperView, throwVelocity: CGPoint) {
        creeperPhysics?.releaseDrag(throwVelocity: throwVelocity)
    }

    // MARK: - Enderman Combat & Spawning (엔더맨 시선 마주침 & 소환)
    public func spawnEnderman() {
        guard endermanWindow == nil else { return }
        let ew = EndermanWindow()
        ew.endermanView.endermanDelegate = self
        self.endermanWindow = ew

        let spawnDir: CGFloat = Bool.random() ? 1.0 : -1.0
        let spawnX = physics.position.x + (spawnDir * 280.0)
        let ePhys = PhysicsEngine(initialPosition: CGPoint(x: spawnX, y: physics.position.y))
        self.endermanPhysics = ePhys
        self.endermanBehavior = EndermanBehaviorController()

        ew.setFeetPosition(x: spawnX, y: physics.position.y)
        ew.orderFrontRegardless()
        ew.endermanView.endermanNode.showOverheadEmoji("👁️ 블록 들고 배회 중...", duration: 2.0)
        SoundAndEffectsManager.shared.play(.pop)
    }

    public func despawnEnderman() {
        endermanWindow?.orderOut(nil)
        endermanWindow = nil
        endermanPhysics = nil
        endermanBehavior = nil
    }

    public func attackEndermanWithCurrentWeapon() {
        guard let ew = endermanWindow,
              let ePhys = endermanPhysics,
              let eBehav = endermanBehavior,
              !eBehav.isDespawned else { return }

        let screen = ScreenEnvironment.shared.screen(for: physics.position)
        let dx = ePhys.position.x - physics.position.x
        window.characterView.characterNode.modelRoot.eulerAngles.y = dx >= 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)

        window.characterView.characterNode.isAttackingWeapon = true
        playerAttackTimer = 0.35

        let weapon = window.characterView.characterNode.currentHeldItem
        let damage = weapon == .diamondSword ? 3 : (weapon == .diamondPickaxe ? 2 : 1)
        window.characterView.characterNode.showOverheadEmoji("⚔️ 엔더맨 타격!", duration: 1.2)

        eBehav.applyDamage(
            damage,
            fromPlayerAt: physics.position,
            weapon: weapon,
            endermanPhysics: ePhys,
            endermanNode: ew.endermanView.endermanNode,
            screen: screen,
            onDefeated: { [weak self] in
                self?.handleEndermanDefeated()
            }
        )
    }

    // MARK: - Skeleton Archer & Combat (스켈레톤 활 쏘기 & 전투)
    public func spawnSkeleton() {
        guard skeletonWindow == nil else { return }
        let sw = SkeletonWindow()
        sw.skeletonView.skeletonDelegate = self
        self.skeletonWindow = sw

        let spawnDir: CGFloat = Bool.random() ? 1.0 : -1.0
        let spawnX = physics.position.x + (spawnDir * 290.0)
        let sPhys = PhysicsEngine(initialPosition: CGPoint(x: spawnX, y: physics.position.y))
        self.skeletonPhysics = sPhys
        self.skeletonBehavior = SkeletonBehaviorController()

        sw.setFeetPosition(x: spawnX, y: physics.position.y)
        sw.orderFrontRegardless()
        sw.skeletonView.skeletonNode.showOverheadEmoji("🏹 딸깍딸깍...", duration: 1.8)
        SoundAndEffectsManager.shared.play(.alert)
    }

    public func despawnSkeleton() {
        skeletonWindow?.orderOut(nil)
        skeletonWindow = nil
        skeletonPhysics = nil
        skeletonBehavior = nil
    }

    private func launchArrowFromSkeleton(from startPos: CGPoint, to targetPos: CGPoint) {
        let arrow = ArrowEntityWindow(
            startPos: startPos,
            targetPos: targetPos,
            checkGuarding: { [weak self] in
                guard let self = self else { return false }
                let char = self.window.characterView.characterNode
                return char.isShieldEquipped && (char.isSneaking || char.isGuarding)
            },
            onHit: { [weak self] isDeflected in
                guard let self = self else { return }
                let char = self.window.characterView.characterNode
                if isDeflected {
                    char.showOverheadEmoji("🛡️ 챙-! 화살 방어!", duration: 2.0)
                    SoundAndEffectsManager.shared.play(.pop)
                } else {
                    char.showOverheadEmoji("💥 아야!", duration: 1.5)
                    self.physics.launch(vx: (self.physics.position.x >= startPos.x ? 120 : -120), vy: 80)
                }
            }
        )
        activeArrows.append(arrow)
        arrow.launch()
    }

    public func attackSkeletonWithCurrentWeapon() {
        guard let sw = skeletonWindow,
              let sPhys = skeletonPhysics,
              let sBehav = skeletonBehavior,
              !sBehav.isDespawned else { return }

        let dx = sPhys.position.x - physics.position.x
        window.characterView.characterNode.modelRoot.eulerAngles.y = dx >= 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)

        window.characterView.characterNode.isAttackingWeapon = true
        playerAttackTimer = 0.35

        let weapon = window.characterView.characterNode.currentHeldItem
        let damage = weapon == .diamondSword ? 3 : (weapon == .diamondPickaxe ? 2 : 1)
        window.characterView.characterNode.showOverheadEmoji("⚔️ 스켈레톤 타격!", duration: 1.2)

        sBehav.applyDamage(
            damage,
            fromPlayerAt: physics.position,
            weapon: weapon,
            skeletonPhysics: sPhys,
            skeletonNode: sw.skeletonView.skeletonNode,
            onDefeated: { [weak self] in
                self?.handleSkeletonDefeated()
            }
        )
    }

    private func handleSkeletonDefeated() {
        window.characterView.characterNode.showOverheadEmoji("🏹 스켈레톤 명중 컷! 뼈다귀 득템! 🦴", duration: 3.2)
        SoundAndEffectsManager.shared.play(.heart)
        physics.jump(impulse: 340)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.despawnSkeleton()
        }
    }

    @objc private func didSelectSpawnSkeleton() {
        spawnSkeleton()
    }

    @objc private func didToggleSkeletonSpawn(_ sender: NSMenuItem) {
        isSkeletonSpawnEnabled.toggle()
        sender.state = isSkeletonSpawnEnabled ? .on : .off
        statusItem?.menu = buildContextMenu()
    }

    // MARK: - SkeletonViewDelegate
    public func skeletonViewDidClick(_ view: SkeletonView) {
        attackSkeletonWithCurrentWeapon()
    }

    public func skeletonViewDidStartDrag(_ view: SkeletonView, at screenPoint: CGPoint) {
        skeletonPhysics?.setDragged(at: screenPoint)
    }

    public func skeletonViewDidDrag(_ view: SkeletonView, to screenPoint: CGPoint) {
        skeletonPhysics?.setDragged(at: screenPoint)
    }

    public func skeletonViewDidEndDrag(_ view: SkeletonView, throwVelocity: CGPoint) {
        skeletonPhysics?.releaseDrag(throwVelocity: throwVelocity)
    }

    private func handleEndermanDefeated() {
        window.characterView.characterNode.showOverheadEmoji("🔮 엔더 진주를 손에 넣었다! 대박!", duration: 3.2)
        SoundAndEffectsManager.shared.play(.heart)
        physics.jump(impulse: 340)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.despawnEnderman()
        }
    }

    @objc private func didSelectSpawnEnderman() {
        spawnEnderman()
    }

    @objc private func didToggleEndermanSpawn(_ sender: NSMenuItem) {
        isEndermanSpawnEnabled.toggle()
        sender.state = isEndermanSpawnEnabled ? .on : .off
        statusItem?.menu = buildContextMenu()
    }

    // MARK: - EndermanViewDelegate
    public func endermanViewDidClick(_ view: EndermanView) {
        attackEndermanWithCurrentWeapon()
    }

    public func endermanViewDidStartDrag(_ view: EndermanView, at screenPoint: CGPoint) {
        endermanPhysics?.setDragged(at: screenPoint)
    }

    public func endermanViewDidDrag(_ view: EndermanView, to screenPoint: CGPoint) {
        endermanPhysics?.setDragged(at: screenPoint)
    }

    public func endermanViewDidEndDrag(_ view: EndermanView, throwVelocity: CGPoint) {
        endermanPhysics?.releaseDrag(throwVelocity: throwVelocity)
    }

    // MARK: - Fishing (낚시)
    @objc private func didSelectFishing() {
        behavior.triggerFishing(characterNode: window.characterView.characterNode)
    }

    // MARK: - Window Squash & Minimize (창 압축 최소화)
    private var squashOverlay: WindowSquashOverlayWindow?

    private func canStartSquashMinimize() -> Bool {

        guard let p = physics?.currentPlatform, case .window = p.kind else { return false }
        return !behavior.isClimbing && !behavior.isTNTActive && squashOverlay == nil
    }

    @objc private func didSelectSquashMinimize() {
        guard let p = physics.currentPlatform, case let .window(winID, _, pid) = p.kind else { return }
        guard let targetFrame = ScreenEnvironment.shared.windowCocoaFrame(windowID: winID) else { return }

        let overlay = WindowSquashOverlayWindow(targetFrame: targetFrame, duration: 2.0) { [weak self] in
            WindowMinimizer.shared.minimize(windowID: winID, pid: pid)
            self?.squashOverlay = nil
        }
        self.squashOverlay = overlay
        overlay.start()
        behavior.startSquashMinimize(on: p, duration: 2.0, characterNode: window.characterView.characterNode)
    }
    // MARK: - Ladder Descent (사다리 타고 창문 내려가기)
    private func canStartLadderDescent() -> Bool {
        guard !behavior.isClimbing,
              let platform = physics?.currentPlatform else { return false }
        return CharacterBehaviorController.canDescend(from: platform)
    }

    @objc private func didToggleShield(_ sender: NSMenuItem) {
        window.characterView.characterNode.isShieldEquipped.toggle()
        sender.state = window.characterView.characterNode.isShieldEquipped ? .on : .off
        statusItem?.menu = buildContextMenu()
        SoundAndEffectsManager.shared.play(.pop)
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
