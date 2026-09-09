import AppKit
import Foundation

public struct CatalogSkinItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let category: String
    public let username: String
    public let details: String
    public let previewURL: URL?

    public init(id: String? = nil, name: String, category: String, username: String, details: String) {
        self.id = id ?? username
        self.name = name
        self.category = category
        self.username = username
        self.details = details
        self.previewURL = SkinDownloaderService.shared.avatarPreviewURL(for: username)
    }
}

public final class SkinCatalogManager {
    public static let shared = SkinCatalogManager()

    public let categories = ["전체", "레전드 & 크리에이터", "몬스터 & 몹", "히어로 & 팝컬처"]

    public let curatedSkins: [CatalogSkinItem] = [
        // 레전드 & 크리에이터
        CatalogSkinItem(
            name: "테크노블레이드 (Technoblade)",
            category: "레전드 & 크리에이터",
            username: "Technoblade",
            details: "전설적인 왕관을 쓴 돼지 전사"
        ),
        CatalogSkinItem(
            name: "노치 (Notch)",
            category: "레전드 & 크리에이터",
            username: "Notch",
            details: "마인크래프트 창시자 마르쿠스 페르손"
        ),
        CatalogSkinItem(
            name: "젭 (jeb_)",
            category: "레전드 & 크리에이터",
            username: "jeb_",
            details: "마인크래프트 수석 개발자 옌스"
        ),
        CatalogSkinItem(
            name: "드림 (Dream)",
            category: "레전드 & 크리에이터",
            username: "Dream",
            details: "유명 스피드러너 초록 스마일 캐릭터"
        ),
        CatalogSkinItem(
            name: "멈보 점보 (Mumbo)",
            category: "레전드 & 크리에이터",
            username: "Mumbo",
            details: "레드스톤 마스터, 정장과 콧수염"
        ),
        CatalogSkinItem(
            name: "그리안 (Grian)",
            category: "레전드 & 크리에이터",
            username: "Grian",
            details: "빨간 스웨터의 유쾌한 건축가"
        ),
        CatalogSkinItem(
            name: "댄TDM (DanTDM)",
            category: "레전드 & 크리에이터",
            username: "DanTDM",
            details: "고글을 쓴 클래식 유튜브 크리에이터"
        ),

        // 몬스터 & 몹
        CatalogSkinItem(
            name: "정장 크리퍼 (Creeper)",
            category: "몬스터 & 몹",
            username: "Creeper",
            details: "깔끔한 턱시도를 차려입은 신사 크리퍼"
        ),
        CatalogSkinItem(
            name: "엔더맨 (Enderman)",
            category: "몬스터 & 몹",
            username: "Enderman",
            details: "보라색 눈빛의 신비로운 엔더맨"
        ),
        CatalogSkinItem(
            name: "스켈레톤 (Skeleton)",
            category: "몬스터 & 몹",
            username: "Skeleton",
            details: "활을 쏘는 해골 궁수"
        ),
        CatalogSkinItem(
            name: "좀비 피그맨 (Pigman)",
            category: "몬스터 & 몹",
            username: "Pigman",
            details: "지옥의 황금 칼 좀비화 피글린"
        ),

        // 히어로 & 팝컬처
        CatalogSkinItem(
            name: "아이언맨 (IronMan)",
            category: "히어로 & 팝컬처",
            username: "IronMan",
            details: "붉은색과 금색의 하이테크 슈트"
        ),
        CatalogSkinItem(
            name: "스파이더맨 (SpiderMan)",
            category: "히어로 & 팝컬처",
            username: "SpiderMan",
            details: "친절한 이웃 거미 영웅"
        ),
        CatalogSkinItem(
            name: "배트맨 (Batman)",
            category: "히어로 & 팝컬처",
            username: "Batman",
            details: "고담시의 어둠의 기사"
        ),
        CatalogSkinItem(
            name: "슈퍼 마리오 (Mario)",
            category: "히어로 & 팝컬처",
            username: "Mario",
            details: "빨간 모자와 멜빵바지 배관공"
        ),
        CatalogSkinItem(
            name: "우주비행사 (Astronaut)",
            category: "히어로 & 팝컬처",
            username: "Astronaut",
            details: "하얀 우주복과 바이저 헬멧"
        )
    ]
}

// MARK: - Local Skin Storage Manager
public final class SkinStorageManager {
    public static let shared = SkinStorageManager()

    public let storageDirectory: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.storageDirectory = appSupport.appendingPathComponent("OhMyFriend/Skins", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    /// Save a skin image data to local library
    @discardableResult
    public func saveSkin(data: Data, name: String) -> URL? {
        let cleanName = name.replacingOccurrences(of: "/", with: "_").trimmingCharacters(in: .whitespaces)
        let fileURL = storageDirectory.appendingPathComponent("\(cleanName).png")
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    /// List all saved local skins
    public func listSavedSkins() -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }
        return files.filter { $0.pathExtension.lowercased() == "png" }
            .sorted { (u1, u2) -> Bool in
                let d1 = (try? u1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? u2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 > d2
            }
    }
}
