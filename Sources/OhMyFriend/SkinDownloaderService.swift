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

    /// Download Minecraft skin from any arbitrary direct image URL
    public func downloadSkin(from url: URL) async throws -> (skin: SkinTexture, image: NSImage, rawData: Data) {
        var req = URLRequest(url: url)
        req.setValue("OhMyFriend-DesktopCompanion/1.0", forHTTPHeaderField: "User-Agent")

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

        guard let image = NSImage(data: data) else {
            throw SkinDownloadError.invalidSkinImage
        }

        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw SkinDownloadError.invalidSkinImage
        }

        // Check Minecraft skin dimensions: standard 64x64, classic 64x32, or HD multiples (128x128, etc.)
        let w = cg.width
        let h = cg.height
        let isValidRatio = (w == 64 && (h == 64 || h == 32)) || (w == 128 && h == 128) || (w == h && w >= 64)
        guard isValidRatio, let skin = SkinTexture(image: image) else {
            throw SkinDownloadError.invalidSkinImage
        }

        return (skin, image, data)
    }

    /// Returns a high-res 3D avatar body render URL for a given username
    public func avatarPreviewURL(for username: String) -> URL? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://minotar.net/armor/body/\(trimmed)/160.png")
    }
}
