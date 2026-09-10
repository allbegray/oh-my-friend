import AppKit

// 9~17차 백로그 중앙 메뉴: "🎉 추가 모션" 서브메뉴 아래 차수별 9개 하위 메뉴.
// 각 배치는 Manager.shared.entries()만 제공하면 되므로 AppController 본문 수정이 불필요하다.

extension AppController {
    func buildExtraMenu() -> NSMenu {
        let root = NSMenu()
        addExtraBatch(root, title: "🌿 야생 동물", entries: WildlifeManager.shared.entries())
        addExtraBatch(root, title: "🌑 어둠·네더 몹", entries: DarkNetherManager.shared.entries())
        addExtraBatch(root, title: "🌊 물과 비", entries: WaterManager.shared.entries())
        addExtraBatch(root, title: "👥 소셜·메타", entries: SocialManager.shared.entries())
        addExtraBatch(root, title: "🧱 레드스톤·꾸미기", entries: RedstoneManager.shared.entries())
        addExtraBatch(root, title: "❄️ 겨울", entries: WinterManager.shared.entries())
        addExtraBatch(root, title: "🏜️ 사막 캐러밴", entries: CaravanManager.shared.entries())
        addExtraBatch(root, title: "🌌 엔드", entries: EndManager.shared.entries())
        addExtraBatch(root, title: "🎪 이벤트", entries: EventManager.shared.entries())
        return root
    }

    func buildExtraMenu2() -> NSMenu {
        let root = NSMenu()
        addExtraBatch(root, title: "👹 신규 몹", entries: MobsAManager.shared.entries())
        addExtraBatch(root, title: "🔥 네더 확장", entries: NetherBManager.shared.entries())
        addExtraBatch(root, title: "🌌 엔드 확장", entries: EndCManager.shared.entries())
        addExtraBatch(root, title: "🌊 바다", entries: SeaDManager.shared.entries())
        addExtraBatch(root, title: "🐾 동물·사육", entries: AnimalsEManager.shared.entries())
        addExtraBatch(root, title: "🧱 레드스톤", entries: RedstoneFManager.shared.entries())
        addExtraBatch(root, title: "🏠 건축·꾸미기", entries: DecorGManager.shared.entries())
        addExtraBatch(root, title: "🪄 마법·전투", entries: MagicHManager.shared.entries())
        addExtraBatch(root, title: "🏛️ 구조물·보스", entries: StructuresIManager.shared.entries())
        addExtraBatch(root, title: "🎭 생활·메타", entries: MetaJManager.shared.entries())
        return root
    }

    // 검색 필터용 그룹 기술자: buildExtraMenu/buildExtraMenu2와 같은 순서·제목.
    // 기존 build 계열은 그대로 두며, MenuSearch.makeSearchableMenu 입력으로만 쓴다.
    func extraGroups() -> [(String, [ExtraMenuEntry])] {
        [
            ("🌿 야생 동물", WildlifeManager.shared.entries()),
            ("🌑 어둠·네더 몹", DarkNetherManager.shared.entries()),
            ("🌊 물과 비", WaterManager.shared.entries()),
            ("👥 소셜·메타", SocialManager.shared.entries()),
            ("🧱 레드스톤·꾸미기", RedstoneManager.shared.entries()),
            ("❄️ 겨울", WinterManager.shared.entries()),
            ("🏜️ 사막 캐러밴", CaravanManager.shared.entries()),
            ("🌌 엔드", EndManager.shared.entries()),
            ("🎪 이벤트", EventManager.shared.entries()),
        ]
    }

    func extraGroups2() -> [(String, [ExtraMenuEntry])] {
        [
            ("👹 신규 몹", MobsAManager.shared.entries()),
            ("🔥 네더 확장", NetherBManager.shared.entries()),
            ("🌌 엔드 확장", EndCManager.shared.entries()),
            ("🌊 바다", SeaDManager.shared.entries()),
            ("🐾 동물·사육", AnimalsEManager.shared.entries()),
            ("🧱 레드스톤", RedstoneFManager.shared.entries()),
            ("🏠 건축·꾸미기", DecorGManager.shared.entries()),
            ("🪄 마법·전투", MagicHManager.shared.entries()),
            ("🏛️ 구조물·보스", StructuresIManager.shared.entries()),
            ("🎭 생활·메타", MetaJManager.shared.entries()),
        ]
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
