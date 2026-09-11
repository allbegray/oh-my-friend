import AppKit
import Foundation

/// GitHub Releases API에서 수신한 최신 릴리스 메타데이터
public struct GitHubReleaseInfo: Sendable {
    public let tagName: String
    public let version: String
    public let title: String
    public let body: String
    public let htmlURL: URL
    public let downloadURL: URL?
    public let assetName: String?
}

/// Oh My Friend 자동 업데이트 전담 관리자
public final class UpdateManager: @unchecked Sendable {
    public static let shared = UpdateManager()

    /// 현재 앱의 번들 버전 (CFBundleShortVersionString 기준, 개발/CLI fallback: 0.39.1)
    public static var currentVersion: String {
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !v.isEmpty, v != "1.0.0" {
            return v
        }
        return "0.39.1"
    }

    /// GitHub 최신 릴리스 확인 엔드포인트
    private let releasesAPIURL = URL(string: "https://api.github.com/repos/allbegray/oh-my-friend/releases/latest")!

    /// 현재 감지된 최신 릴리스 정보 (업데이트 가능 시 보관)
    public private(set) var availableUpdate: GitHubReleaseInfo?

    /// 업데이트 확인/다운로드 진행 중 여부
    public private(set) var isChecking: Bool = false
    public private(set) var isUpdating: Bool = false

    /// 업데이트 상태 변경 리스너 (메뉴바 텍스트 등 실시간 갱신용)
    public var onUpdateStatusChanged: ((GitHubReleaseInfo?) -> Void)?

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: config)
    }

    /// 시맨틱 버전(Major.Minor.Patch) 비교: v1이 v2보다 크면 true
    public static func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let clean1 = v1.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).components(separatedBy: "-")[0]
        let clean2 = v2.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).components(separatedBy: "-")[0]

        let parts1 = clean1.split(separator: ".").compactMap { Int($0) }
        let parts2 = clean2.split(separator: ".").compactMap { Int($0) }

        let count = max(parts1.count, parts2.count)
        for i in 0..<count {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }

    /// 최신 릴리스 확인
    /// - Parameter manual: 사용자가 메뉴를 클릭해 명시적으로 요청했는지 여부 (true 시 최신 상태/오류 다이얼로그 노출)
    public func checkForUpdates(manual: Bool = false, completion: ((GitHubReleaseInfo?) -> Void)? = nil) {
        guard !isChecking else { return }
        isChecking = true

        Task { [weak self] in
            guard let self = self else { return }
            defer {
                DispatchQueue.main.async {
                    self.isChecking = false
                }
            }

            var request = URLRequest(url: self.releasesAPIURL)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("OhMyFriend/\(Self.currentVersion) (Macintosh; macOS)", forHTTPHeaderField: "User-Agent")

            do {
                let (data, response) = try await self.session.data(for: request)
                guard let httpRes = response as? HTTPURLResponse else {
                    throw NSError(domain: "UpdateManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "응답을 파싱할 수 없습니다."])
                }

                guard httpRes.statusCode == 200 else {
                    let msg = httpRes.statusCode == 404 ? "릴리스를 찾을 수 없습니다." : "서버 응답 오류 (HTTP \(httpRes.statusCode))"
                    throw NSError(domain: "UpdateManager", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlURLStr = json["html_url"] as? String,
                      let htmlURL = URL(string: htmlURLStr) else {
                    throw NSError(domain: "UpdateManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "릴리스 데이터 형식이 올바르지 않습니다."])
                }

                let cleanVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                let title = json["name"] as? String ?? "v\(cleanVersion)"
                let body = json["body"] as? String ?? ""

                // 바이너리 Asset 탐색 (OhMyFriend-macOS-arm64.zip 또는 .zip)
                var downloadURL: URL?
                var assetName: String?
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           name.hasSuffix(".zip"),
                           let dlStr = asset["browser_download_url"] as? String,
                           let dlURL = URL(string: dlStr) {
                            assetName = name
                            downloadURL = dlURL
                            if name.contains("arm64") {
                                break
                            }
                        }
                    }
                }

                let releaseInfo = GitHubReleaseInfo(
                    tagName: tagName,
                    version: cleanVersion,
                    title: title,
                    body: body,
                    htmlURL: htmlURL,
                    downloadURL: downloadURL,
                    assetName: assetName
                )

                let hasUpdate = Self.isVersion(cleanVersion, greaterThan: Self.currentVersion)

                DispatchQueue.main.async {
                    if hasUpdate {
                        self.availableUpdate = releaseInfo
                        self.onUpdateStatusChanged?(releaseInfo)
                        completion?(releaseInfo)
                        if manual {
                            self.promptUpdateAlert(for: releaseInfo)
                        }
                    } else {
                        self.availableUpdate = nil
                        self.onUpdateStatusChanged?(nil)
                        completion?(nil)
                        if manual {
                            self.showUpToDateAlert()
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if manual {
                        self.showErrorAlert(error.localizedDescription)
                    }
                    completion?(nil)
                }
            }
        }
    }

    /// 이미 최신 버전일 때 다이얼로그
    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "최신 버전을 사용하고 있습니다"
        alert.informativeText = "현재 설치된 Oh My Friend (v\(Self.currentVersion))가 가장 최신 버전입니다."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    /// 오류 발생 시 다이얼로그
    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "업데이트 확인 실패"
        alert.informativeText = "업데이트를 확인하는 도중 오류가 발생했습니다:\n\(message)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    /// 새 버전 발견 시 업데이트 안내 다이얼로그
    public func promptUpdateAlert(for release: GitHubReleaseInfo) {
        let alert = NSAlert()
        alert.messageText = "🚀 새로운 버전(v\(release.version))이 출시되었습니다!"

        var notes = release.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if notes.count > 350 {
            notes = String(notes.prefix(350)) + "..."
        }
        if notes.isEmpty {
            notes = "새로운 기능 개선 및 버그 수정이 포함되어 있습니다."
        }

        alert.informativeText = """
        현재 버전: v\(Self.currentVersion)
        최신 버전: v\(release.version) (\(release.title))

        [릴리스 주요 내용]
        \(notes)
        """
        alert.alertStyle = .informational

        if release.downloadURL != nil {
            alert.addButton(withTitle: "지금 업데이트 (자동 설치 및 재시작)")
            alert.addButton(withTitle: "릴리스 페이지 보기")
            alert.addButton(withTitle: "나중에")
        } else {
            alert.addButton(withTitle: "릴리스 페이지에서 다운로드")
            alert.addButton(withTitle: "나중에")
        }

        let response = alert.runModal()
        if release.downloadURL != nil {
            switch response {
            case .alertFirstButtonReturn:
                self.performAutoUpdate(for: release)
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(release.htmlURL)
            default:
                break
            }
        } else {
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(release.htmlURL)
            }
        }
    }

    /// 백그라운드 다운로드 및 인플레이스 앱 교체 재실행
    public func performAutoUpdate(for release: GitHubReleaseInfo) {
        guard let downloadURL = release.downloadURL else {
            NSWorkspace.shared.open(release.htmlURL)
            return
        }

        guard !isUpdating else { return }
        isUpdating = true

        // 다운로드 안내 알림
        let progressAlert = NSAlert()
        progressAlert.messageText = "Oh My Friend v\(release.version) 다운로드 중..."
        progressAlert.informativeText = "최신 버전을 다운로드하여 설치를 준비하고 있습니다.\n완료되면 앱이 자동으로 재시작됩니다."
        progressAlert.alertStyle = .informational
        progressAlert.addButton(withTitle: "백그라운드에서 진행")

        DispatchQueue.main.async {
            progressAlert.runModal()
        }

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("OhMyFriendUpdate_\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                let zipDest = tempDir.appendingPathComponent("update.zip")
                let (tempLocalURL, _) = try await self.session.download(from: downloadURL)
                try FileManager.default.moveItem(at: tempLocalURL, to: zipDest)

                // 압축 해제: macOS 내장 ditto 사용 (권한 및 심볼릭 링크 온전 보존)
                let extractDir = tempDir.appendingPathComponent("extracted")
                try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

                let dittoProc = Process()
                dittoProc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                dittoProc.arguments = ["-xk", zipDest.path, extractDir.path]
                try dittoProc.run()
                dittoProc.waitUntilExit()

                guard dittoProc.terminationStatus == 0 else {
                    throw NSError(domain: "UpdateManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "업데이트 압축 파일 해제에 실패했습니다."])
                }

                // 압축 해제된 폴더에서 OhMyFriend.app 검색
                let fileManager = FileManager.default
                let extractedItems = try fileManager.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
                guard let newAppBundle = extractedItems.first(where: { $0.lastPathComponent == "OhMyFriend.app" }) else {
                    throw NSError(domain: "UpdateManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "다운로드된 패키지에서 OhMyFriend.app을 찾을 수 없습니다."])
                }

                // 현재 실행 중인 앱의 번들 경로 파악
                let currentBundle = Bundle.main.bundleURL
                let isRunningInsideAppBundle = currentBundle.pathExtension == "app"

                if isRunningInsideAppBundle {
                    // 독립 셸 스크립트로 현재 프로세스 종료 대기 -> 앱 번들 덮어쓰기 -> 격리 해제 -> open 실행
                    let scriptURL = tempDir.appendingPathComponent("relaunch.sh")
                    let currentPID = ProcessInfo.processInfo.processIdentifier

                    let scriptContent = """
                    #!/bin/bash
                    while kill -0 \(currentPID) 2>/dev/null; do
                        sleep 0.15
                    done
                    rm -rf "\(currentBundle.path)"
                    cp -R "\(newAppBundle.path)" "\(currentBundle.path)"
                    xattr -cr "\(currentBundle.path)" 2>/dev/null || true
                    open "\(currentBundle.path)"
                    rm -rf "\(tempDir.path)"
                    """

                    try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

                    let chmodProc = Process()
                    chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
                    chmodProc.arguments = ["+x", scriptURL.path]
                    try chmodProc.run()
                    chmodProc.waitUntilExit()

                    let relaunchProc = Process()
                    relaunchProc.executableURL = URL(fileURLWithPath: "/bin/bash")
                    relaunchProc.arguments = [scriptURL.path]
                    try relaunchProc.run()

                    DispatchQueue.main.async {
                        NSApp.terminate(nil)
                    }
                } else {
                    // 개발 환경(CLI/SPM 직접 실행) 등 app 번들 외부 실행 시에는 Finder에서 표시
                    DispatchQueue.main.async {
                        self.isUpdating = false
                        let alert = NSAlert()
                        alert.messageText = "업데이트 다운로드 완료"
                        alert.informativeText = "새 버전(v\(release.version))이 준비되었습니다.\nFinder에서 열어 교체하시겠습니까?"
                        alert.addButton(withTitle: "Finder에서 보기")
                        alert.addButton(withTitle: "닫기")
                        if alert.runModal() == .alertFirstButtonReturn {
                            NSWorkspace.shared.activateFileViewerSelecting([newAppBundle])
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isUpdating = false
                    self.showErrorAlert("업데이트 설치 중 오류 발생: \(error.localizedDescription)")
                }
            }
        }
    }
}
