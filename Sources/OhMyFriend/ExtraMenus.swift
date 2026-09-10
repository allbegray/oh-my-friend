import AppKit

// 9~17차 백로그 중앙 메뉴: "🎉 추가 모션" 서브메뉴 아래 차수별 9개 하위 메뉴.
// 각 배치는 Manager.shared.entries()만 제공하면 되므로 AppController 본문 수정이 불필요하다.

extension AppController {
    func buildExtraMenu() -> NSMenu {
        let root = NSMenu()
        addExtraBatch(root, title: "🌿 야생 동물 (9차)", entries: WildlifeManager.shared.entries())
        addExtraBatch(root, title: "🌑 어둠·네더 몹 (10차)", entries: DarkNetherManager.shared.entries())
        addExtraBatch(root, title: "🌊 물과 비 (11차)", entries: WaterManager.shared.entries())
        addExtraBatch(root, title: "👥 소셜·메타 (12차)", entries: SocialManager.shared.entries())
        addExtraBatch(root, title: "🧱 레드스톤·꾸미기 (13차)", entries: RedstoneManager.shared.entries())
        addExtraBatch(root, title: "❄️ 겨울 (14차)", entries: WinterManager.shared.entries())
        addExtraBatch(root, title: "🏜️ 사막 캐러밴 (15차)", entries: CaravanManager.shared.entries())
        addExtraBatch(root, title: "🌌 엔드 (16차)", entries: EndManager.shared.entries())
        addExtraBatch(root, title: "🎪 이벤트 (17차)", entries: EventManager.shared.entries())
        return root
    }

    func buildExtraMenu2() -> NSMenu {
        let root = NSMenu()
        addExtraBatch(root, title: "👹 신규 몹 (A)", entries: MobsAManager.shared.entries())
        addExtraBatch(root, title: "🔥 네더 확장 (B)", entries: NetherBManager.shared.entries())
        addExtraBatch(root, title: "🌌 엔드 확장 (C)", entries: EndCManager.shared.entries())
        addExtraBatch(root, title: "🌊 바다 (D)", entries: SeaDManager.shared.entries())
        addExtraBatch(root, title: "🐾 동물·사육 (E)", entries: AnimalsEManager.shared.entries())
        addExtraBatch(root, title: "🧱 레드스톤 (F)", entries: RedstoneFManager.shared.entries())
        addExtraBatch(root, title: "🏠 건축·꾸미기 (G)", entries: DecorGManager.shared.entries())
        addExtraBatch(root, title: "🪄 마법·전투 (H)", entries: MagicHManager.shared.entries())
        addExtraBatch(root, title: "🏛️ 구조물·보스 (I)", entries: StructuresIManager.shared.entries())
        addExtraBatch(root, title: "🎭 생활·메타 (J)", entries: MetaJManager.shared.entries())
        return root
    }

    private func addExtraBatch(_ root: NSMenu, title: String, entries: [ExtraMenuEntry]) {
        let sub = NSMenu()
        for e in entries {
            sub.addItem(ClosureMenuItem(e))
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = sub
        root.addItem(item)
    }
}
