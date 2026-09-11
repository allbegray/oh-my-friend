import AppKit

/// 옛 이름(Oh My Friend) 시절의 사용자 데이터를 새 이름(Oh Mine Friend)으로 옮긴다.
///
/// 앱 이름과 번들 식별자를 바꾸면 macOS 는 이를 **다른 앱**으로 취급한다. 그 결과
/// `UserDefaults` 는 새 번들 ID 의 빈 도메인을 읽고, 스킨 보관함 경로도 달라져
/// 기존 사용자가 쌓아둔 데이터가 전부 고아가 된다. 이 클래스가 그 두 가지를 1회 이전한다.
///
/// 접근성(Accessibility) 권한은 TCC 가 번들 ID 로 묶어 관리하고 SIP 로 보호되므로
/// 코드로 옮길 수 없다 — 사용자가 시스템 설정에서 한 번 다시 허용해야 한다.
public enum LegacyMigration {
    /// 옛 번들 식별자
    private static let legacyBundleID = "com.hong.ohmyfriend"
    private static let legacyAppSupportFolder = "OhMyFriend"
    private static let currentAppSupportFolder = "OhMineFriend"

    /// 새 도메인에서 "이미 이전했다"를 표시하는 키
    private static let completedKey = "legacyMigrationFromOhMyFriend"

    /// 앱 시작 시 1회 호출. 어떤 단계가 실패해도 앱은 계속 떠야 하므로 예외를 던지지 않는다.
    public static func runIfNeeded() {
        let defaults = UserDefaults.standard
        let alreadyDone = defaults.bool(forKey: completedKey)

        migrateApplicationSupport(dryRun: alreadyDone)

        guard !alreadyDone else { return }

        let migrated = migrateUserDefaults(into: defaults)
        defaults.set(true, forKey: completedKey)
        // cfprefsd 가 즉시 반영하도록 강제 저장 (이후 읽기가 기본값으로 떨어지지 않게).
        defaults.synchronize()

        if migrated > 0 {
            print("🔁 이전 완료: 옛 Oh My Friend 설정 \(migrated)개를 Oh Mine Friend 로 옮겼습니다.")
        }
    }

    // MARK: - UserDefaults

    /// 옛 도메인의 앱 소유 키만 새 도메인으로 복사한다.
    ///
    /// `dictionaryRepresentation()` 전체를 복사하지 않는 이유: 비샌드박스 앱의 도메인에는
    /// `NSWindow Frame ...`, `MetaJStats...` 같은 시스템 항목이 섞여 있어, 통째로 옮기면
    /// 무관한 설정까지 끌어온다. 그래서 앱이 실제로 쓰는 키만 화이트리스트로 고른다.
    ///
    /// - Important: 새 `UserDefaults` 키를 추가하면 아래 목록에도 넣어야 이전된다.
    @discardableResult
    private static func migrateUserDefaults(into defaults: UserDefaults) -> Int {
        guard let legacy = UserDefaults(suiteName: legacyBundleID),
              let legacyValues = legacy.dictionaryRepresentation() as? [String: Any]
        else { return 0 }

        var ownedKeys = Set<String>([
            "stageBrightness",
            "isLightingEffectEnabled",
            "isWeatherEnabled",
            "preferredCreeperLegType",
        ])
        // 발전 과제는 ID 마다 `adv_<id>` 키를 쓴다 (하드코딩 대신 enum 에서 파생).
        for id in AdvancementID.allCases {
            ownedKeys.insert("adv_\(id.rawValue)")
        }
        // 스폰 나침반은 `SpawnCompass.*` 접두어를 쓴다.
        for key in legacyValues.keys where key.hasPrefix("SpawnCompass.") {
            ownedKeys.insert(key)
        }

        var migrated = 0
        for key in ownedKeys {
            guard let value = legacyValues[key] else { continue }
            // 새 도메인에 이미 값이 있으면(사용자가 새 버전에서 이미 설정했으면) 덮어쓰지 않는다.
            if defaults.object(forKey: key) != nil { continue }
            defaults.set(value, forKey: key)
            migrated += 1
        }
        return migrated
    }

    // MARK: - Application Support (스킨 보관함)

    /// `~/Library/Application Support/OhMyFriend/Skins` → `.../OhMineFriend/Skins`
    ///
    /// - Parameter dryRun: 이전이 이미 끝난 뒤라면 폴더를 새로 만들지 않는다.
    ///   (매 실행마다 빈 폴더를 만들면 사용자가 지운 폴더가 되살아난다.)
    private static func migrateApplicationSupport(dryRun: Bool) {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let legacyDir = appSupport.appendingPathComponent(legacyAppSupportFolder, isDirectory: true)
        let currentDir = appSupport.appendingPathComponent(currentAppSupportFolder, isDirectory: true)

        if dryRun {
            try? fm.createDirectory(at: currentDir.appendingPathComponent("Skins", isDirectory: true),
                                    withIntermediateDirectories: true)
            return
        }

        // 옛 폴더가 없으면 새 폴더만 보장하고 끝.
        guard fm.fileExists(atPath: legacyDir.path) else {
            try? fm.createDirectory(at: currentDir.appendingPathComponent("Skins", isDirectory: true),
                                    withIntermediateDirectories: true)
            return
        }

        // 새 폴더가 이미 있으면 옛 내용을 덮어쓰지 않고 병합한다(같은 파일명은 새 것을 신뢰).
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: currentDir.path, isDirectory: &isDir), isDir.boolValue {
            mergeDirectory(from: legacyDir, into: currentDir)
            try? fm.removeItem(at: legacyDir)
        } else {
            do {
                try fm.moveItem(at: legacyDir, to: currentDir)
            } catch {
                // 이동 실패(권한 등) 시 복사로 폴백한다. 원본은 남겨 데이터를 잃지 않는다.
                mergeDirectory(from: legacyDir, into: currentDir)
            }
        }
        try? fm.createDirectory(at: currentDir.appendingPathComponent("Skins", isDirectory: true),
                                withIntermediateDirectories: true)
    }

    /// 옛 폴더의 파일을 새 폴더로 복사한다(이미 있는 파일은 건너뛴다).
    private static func mergeDirectory(from source: URL, into destination: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) else { return }
        try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for item in items {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            guard !fm.fileExists(atPath: target.path) else { continue }
            try? fm.copyItem(at: item, to: target)
        }
    }
}
