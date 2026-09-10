import AppKit
import Foundation

public enum SkinDownloadError: LocalizedError {
    case invalidUsername
    case invalidURL
    case networkError(String)
    case invalidSkinImage
    case notFound

    public var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "유효하지 않은 마인크래프트 닉네임입니다."
        case .invalidURL:
            return "유효하지 않은 웹 주소(URL)입니다."
        case .networkError(let msg):
            return "네트워크 오류: \(msg)"
        case .invalidSkinImage:
            return "올바른 마인크래프트 스킨 이미지(64x64 PNG 등)가 아닙니다."
        case .notFound:
            return "해당 플레이어 또는 스킨을 찾을 수 없습니다."
        }
    }
}

public final class SkinDownloaderService {
    public static let shared = SkinDownloaderService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 20.0
        self.session = URLSession(configuration: config)
    }

    /// Download Minecraft skin PNG directly by player username
    public func downloadSkinByUsername(_ username: String) async throws -> (skin: SkinTexture, image: NSImage, rawData: Data) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SkinDownloadError.invalidUsername
        }

        // Minecraft Java username validation (1~16 alphanumeric or underscore)
        let usernameRegex = "^[a-zA-Z0-9_]{1,16}$"
        guard trimmed.range(of: usernameRegex, options: .regularExpression) != nil else {
            throw SkinDownloadError.invalidUsername
        }

        // 1. Primary Source: Official Mojang Profile API (Single Source of Truth)
        if let mojangProfileURL = URL(string: "https://api.mojang.com/users/profiles/minecraft/\(trimmed)") {
            var req = URLRequest(url: mojangProfileURL)
            req.setValue("OhMyFriend/1.0 (Macintosh; Mac OS X)", forHTTPHeaderField: "User-Agent")

            do {
                let (profileData, profileRes) = try await session.data(for: req)
                if let pHttp = profileRes as? HTTPURLResponse {
                    // [Case A] Mojang 404 / 204: 플레이어가 전 세계에 존재하지 않는 것이 확실하므로 즉시 종료
                    if pHttp.statusCode == 404 || pHttp.statusCode == 204 {
                        throw SkinDownloadError.notFound
                    }

                    // [Case B] 200 OK: 유효한 정품 플레이어 -> UUID 기반 텍스처 조회
                    if pHttp.statusCode == 200,
                       let pJson = try? JSONSerialization.jsonObject(with: profileData) as? [String: Any],
                       let uuid = pJson["id"] as? String, !uuid.isEmpty {

                        // 1-A. Mojang Session Server -> Official textures.minecraft.net CDN
                        if let sessionURL = URL(string: "https://sessionserver.mojang.com/session/minecraft/profile/\(uuid)") {
                            var sessionReq = URLRequest(url: sessionURL)
                            sessionReq.setValue("OhMyFriend/1.0 (Macintosh; Mac OS X)", forHTTPHeaderField: "User-Agent")

                            if let (sessionData, sessionRes) = try? await session.data(for: sessionReq),
                               let sHttp = sessionRes as? HTTPURLResponse, sHttp.statusCode == 200,
                               let sJson = try? JSONSerialization.jsonObject(with: sessionData) as? [String: Any],
                               let properties = sJson["properties"] as? [[String: Any]],
                               let texturesProp = properties.first(where: { ($0["name"] as? String) == "textures" }),
                               let base64Val = texturesProp["value"] as? String,
                               let decodedData = Data(base64Encoded: base64Val),
                               let decodedJson = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any],
                               let texturesDict = decodedJson["textures"] as? [String: Any],
                               let skinDict = texturesDict["SKIN"] as? [String: Any],
                               let skinURLString = skinDict["url"] as? String,
                               let textureURL = URL(string: skinURLString.replacingOccurrences(of: "http://", with: "https://")) {
                                do {
                                    return try await downloadSkin(from: textureURL)
                                } catch {
                                    // Fallback to Crafatar
                                }
                            }
                        }

                        // 1-B. Fallback: Crafatar (UUID 기반)
                        if let crafatarURL = URL(string: "https://crafatar.com/skins/\(uuid)") {
                            do {
                                return try await downloadSkin(from: crafatarURL)
                            } catch {
                                // Fallback to Minotar
                            }
                        }

                        // 1-C. Fallback: Minotar (정품 유저는 맞으나 위 서비스 지연 시)
                        if let minotarURL = URL(string: "https://minotar.net/skin/\(trimmed)") {
                            do {
                                return try await downloadSkin(from: minotarURL)
                            } catch {
                                // All failed
                            }
                        }

                        throw SkinDownloadError.notFound
                    }
                }
            } catch let error as SkinDownloadError {
                // 404 notFound 등 의도된 오류는 Minotar로 우회하지 않고 즉시 throw
                throw error
            } catch {
                // 네트워크 타임아웃, 연결 실패, 5xx 서버 오류 시에만 하단 Minotar 비상 대체 검색으로 진행
            }
        }

        // [Case C] 비상 대체 검색: Mojang API 자체가 네트워크 단절/5xx 서버 오류로 다운된 경우 Minotar로 이중 검색 시도
        if let minotarURL = URL(string: "https://minotar.net/skin/\(trimmed)") {
            do {
                return try await downloadSkin(from: minotarURL)
            } catch {
                // Not found
            }
        }

        throw SkinDownloadError.notFound
    }

    /// Download Minecraft skin from any arbitrary direct image URL or web skin page (Laby.net, NameMC, Skindex, etc.)
    public func downloadSkin(from url: URL) async throws -> (skin: SkinTexture, image: NSImage, rawData: Data) {
        // 1. Handle Laby.net URLs
        if let host = url.host?.lowercased(), host.contains("laby.net") {
            // A) laby.net/@Username
            if url.path.hasPrefix("/@") {
                let username = String(url.path.dropFirst(2))
                if !username.isEmpty {
                    return try await downloadSkinByUsername(username)
                }
            }

            // B) laby.net/skins/<hash> -> Convert directly to https://laby.net/texture/<hash>.png
            // Bypasses Cloudflare HTML challenge on web pages
            for comp in url.pathComponents {
                let clean = comp.replacingOccurrences(of: ".png", with: "")
                if clean.count == 32 && clean.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil {
                    if let directURL = URL(string: "https://laby.net/texture/\(clean).png"), directURL != url {
                        return try await downloadSkin(from: directURL)
                    }
                }
            }
        }

        var req = URLRequest(url: url)
        req.setValue("OhMyFriend/1.0 (Macintosh; Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw SkinDownloadError.networkError(error.localizedDescription)
        }

        guard let httpRes = response as? HTTPURLResponse else {
            throw SkinDownloadError.networkError("응답 없음")
        }

        guard httpRes.statusCode == 200 else {
            if httpRes.statusCode == 404 {
                throw SkinDownloadError.notFound
            }
            throw SkinDownloadError.networkError("HTTP 상태 코드: \(httpRes.statusCode)")
        }

        // Check if data is already a valid Minecraft skin image
        if let image = NSImage(data: data),
           let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let w = cg.width
            let h = cg.height
            let isValidRatio = (w == 64 && (h == 64 || h == 32)) || (w == 128 && h == 128) || (w == h && w >= 64)
            if isValidRatio, let skin = SkinTexture(image: image) {
                return (skin, image, data)
            }
        }

        // If not a direct image (or web page like laby.net/skins/<hash>, NameMC, etc.), parse HTML for Minecraft texture URL
        if let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
            // Pattern 1: Official Mojang texture server (Used by laby.net, NameMC, etc.)
            let mojangPattern = #"https?://textures\.minecraft\.net/texture/([a-f0-9]{32,64})"#
            if let regex = try? NSRegularExpression(pattern: mojangPattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               let range = Range(match.range, in: html),
               let textureURL = URL(string: String(html[range])) {
                return try await downloadSkin(from: textureURL)
            }

            // Pattern 2: Direct texture PNG link inside web page
            let pngPattern = #"https?://[^\s"'<>]+\.png"#
            if let regex = try? NSRegularExpression(pattern: pngPattern, options: []) {
                let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
                for m in matches {
                    if let r = Range(m.range, in: html),
                       let candidateURL = URL(string: String(html[r])) {
                        do {
                            let res = try await downloadSkin(from: candidateURL)
                            return res
                        } catch {
                            continue
                        }
                    }
                }
            }
        }

        throw SkinDownloadError.invalidSkinImage
    }

    /// Returns a high-res 3D avatar body render URL for a given username
    public func avatarPreviewURL(for username: String) -> URL? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://mc-heads.net/body/\(trimmed)/160")
    }
}
