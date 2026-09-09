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

        // Primary source: Minotar direct skin API
        if let minotarURL = URL(string: "https://minotar.net/skin/\(trimmed)") {
            do {
                return try await downloadSkin(from: minotarURL)
            } catch {
                // Fallback to Crafatar via Mojang UUID
            }
        }

        // Fallback: Query Mojang API for UUID then Crafatar
        guard let mojangURL = URL(string: "https://api.mojang.com/users/profiles/minecraft/\(trimmed)") else {
            throw SkinDownloadError.invalidUsername
        }

        let (data, response) = try await session.data(from: mojangURL)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw SkinDownloadError.notFound
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uuid = json["id"] as? String else {
            throw SkinDownloadError.notFound
        }

        guard let crafatarURL = URL(string: "https://crafatar.com/skins/\(uuid)") else {
            throw SkinDownloadError.notFound
        }

        return try await downloadSkin(from: crafatarURL)
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
        return URL(string: "https://minotar.net/armor/body/\(trimmed)/160.png")
    }
}
