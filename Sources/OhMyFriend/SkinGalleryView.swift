import AppKit
import SwiftUI

public struct SkinGalleryView: View {
    @State private var selectedTab: Int = 0
    @State private var selectedCategory: String = "전체"

    // Search tab states
    @State private var searchUsername: String = ""
    @State private var isSearching: Bool = false
    @State private var searchError: String?
    @State private var searchResultImage: NSImage?
    @State private var searchResultSkin: SkinTexture?
    @State private var searchResultData: Data?

    // URL tab states
    @State private var customURLString: String = ""
    @State private var isDownloadingURL: Bool = false
    @State private var urlError: String?

    // Notification / Toast
    @State private var toastMessage: String?

    // Saved skins list
    @State private var savedSkins: [URL] = []

    public let onApplySkin: (SkinTexture, String) -> Void

    public init(onApplySkin: @escaping (SkinTexture, String) -> Void) {
        self.onApplySkin = onApplySkin
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Main Tab Content
            TabView(selection: $selectedTab) {
                popularGalleryTab
                    .tag(0)
                    .tabItem {
                        Label("인기 스킨 갤러리", systemImage: "sparkles")
                    }

                usernameSearchTab
                    .tag(1)
                    .tabItem {
                        Label("플레이어 닉네임 검색", systemImage: "magnifyingglass")
                    }

                webAndURLTab
                    .tag(2)
                    .tabItem {
                        Label("웹 사이트 & URL", systemImage: "globe")
                    }

                savedLibraryTab
                    .tag(3)
                    .tabItem {
                        Label("내 보관함", systemImage: "folder")
                    }
            }
            .padding()

            // Toast feedback bar
            if let toast = toastMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button("닫기") {
                        toastMessage = nil
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .transition(.move(edge: .bottom))
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .onAppear {
            reloadSavedSkins()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image(systemName: "tshirt.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("마인크래프트 스킨 갤러리 & 다운로더")
                    .font(.headline)
                Text("인기 스킨을 선택하거나 플레이어 닉네임으로 원하는 스킨을 다운로드하여 즉시 입혀보세요.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Tab 1: Popular Gallery
    private var popularGalleryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category Filter Picker
            Picker("카테고리", selection: $selectedCategory) {
                ForEach(SkinCatalogManager.shared.categories, id: \.self) { cat in
                    Text(cat).tag(cat)
                }
            }
            .pickerStyle(.segmented)

            // Grid of Skins
            ScrollView {
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ]

                LazyVGrid(columns: columns, spacing: 12) {
                    let items = SkinCatalogManager.shared.curatedSkins.filter {
                        selectedCategory == "전체" || $0.category == selectedCategory
                    }

                    ForEach(items) { item in
                        skinCard(for: item)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func skinCard(for item: CatalogSkinItem) -> some View {
        HStack(spacing: 12) {
            // Avatar Preview
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 60, height: 90)

                if let url = item.previewURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 54, height: 84)
                        case .failure:
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                        case .empty:
                            ProgressView()
                                .scaleEffect(0.6)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)

                Text(item.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Spacer()

                HStack(spacing: 8) {
                    Button("입히기 (Apply)") {
                        applySkinFromCatalog(item)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        saveSkinToDownloads(item)
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("PNG 파일로 다운로드")
                }
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Tab 2: Username Search
    private var usernameSearchTab: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("마인크래프트 정품 플레이어 닉네임 (예: Technoblade, Notch, Mumbo...)", text: $searchUsername)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performUsernameSearch()
                    }

                Button {
                    performUsernameSearch()
                } label: {
                    if isSearching {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Label("검색 및 다운로드", systemImage: "arrow.down.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchUsername.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
            }

            if let err = searchError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(err)
                        .foregroundColor(.red)
                        .font(.caption)
                    Spacer()
                }
            }

            // Search Result Display
            if let img = searchResultImage, let skin = searchResultSkin {
                VStack(spacing: 12) {
                    HStack(spacing: 24) {
                        // 3D Avatar Render
                        if let previewURL = SkinDownloaderService.shared.avatarPreviewURL(for: searchUsername) {
                            AsyncImage(url: previewURL) { phase in
                                if let render = phase.image {
                                    render
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 90, height: 140)
                                } else {
                                    ProgressView()
                                }
                            }
                        }

                        // 64x64 Skin texture raw preview
                        VStack(alignment: .leading, spacing: 6) {
                            Text("검색 성공: \(searchUsername)")
                                .font(.headline)

                            Text("64x64 PNG 스킨 데이터 수신 완료")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Image(nsImage: img)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .border(Color.secondary, width: 1)

                            HStack(spacing: 10) {
                                Button("✨ 내 캐릭터에 바로 적용하기") {
                                    onApplySkin(skin, searchUsername)
                                    showToast("\(searchUsername) 스킨을 착용했습니다!")
                                    if let data = searchResultData {
                                        SkinStorageManager.shared.saveSkin(data: data, name: searchUsername)
                                        reloadSavedSkins()
                                    }
                                }
                                .buttonStyle(.borderedProminent)

                                Button("다운로드 폴더에 저장") {
                                    if let data = searchResultData {
                                        exportToDownloads(data: data, filename: "\(searchUsername).png")
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("마인크래프트 플레이어의 닉네임을 입력하여 전 세계 플레이어의 스킨을 가져올 수 있습니다.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Tab 3: Web Sites & Direct URL
    private var webAndURLTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("추천 마인크래프트 스킨 사이트")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                siteButton(name: "Laby.net", subtitle: "글로벌 스킨 & 케이프 (laby.net/skins)", urlString: "https://laby.net/skins")
                siteButton(name: "NameMC", subtitle: "스킨 랭킹 & 프로필 검색", urlString: "https://namemc.com/minecraft-skins")
                siteButton(name: "The Skindex", subtitle: "최대 규모 스킨 커뮤니티", urlString: "https://www.minecraftskins.com/")
                siteButton(name: "Planet Minecraft", subtitle: "고품질 크리에이티브 스킨", urlString: "https://www.planetminecraft.com/skins/")
            }

            Divider().padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("스킨 웹페이지 주소 또는 직링크(URL) 입력")
                    .font(.headline)
                Text("💡 Laby.net 스킨 주소(https://laby.net/skins/...)나 NameMC 링크를 그대로 붙여넣어도 원본 스킨을 자동으로 추출합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                TextField("예: https://laby.net/skins/... 또는 https://...skin.png", text: $customURLString)
                    .textFieldStyle(.roundedBorder)

                Button {
                    downloadFromCustomURL()
                } label: {
                    if isDownloadingURL {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Text("다운로드 & 적용")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(customURLString.trimmingCharacters(in: .whitespaces).isEmpty || isDownloadingURL)
            }

            if let err = urlError {
                Text(err)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
    }

    private func siteButton(name: String, subtitle: String, urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name).font(.headline)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 4: Saved Library
    private var savedLibraryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("다운로드 및 보관된 스킨 (\(savedSkins.count)개)")
                    .font(.headline)
                Spacer()
                Button("새로고침") {
                    reloadSavedSkins()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("폴더 열기") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: SkinStorageManager.shared.storageDirectory.path)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if savedSkins.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("아직 저장된 스킨이 없습니다.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(savedSkins, id: \.self) { fileURL in
                            savedSkinRow(fileURL: fileURL)
                        }
                    }
                }
            }
        }
    }

    private func savedSkinRow(fileURL: URL) -> some View {
        HStack(spacing: 12) {
            if let img = NSImage(contentsOf: fileURL) {
                Image(nsImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .border(Color.secondary.opacity(0.4), width: 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(fileURL.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                Text(fileURL.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("입히기") {
                if let skin = SkinTexture.load(from: fileURL) {
                    onApplySkin(skin, fileURL.deletingPathExtension().lastPathComponent)
                    showToast("\(fileURL.deletingPathExtension().lastPathComponent) 스킨을 적용했습니다!")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("삭제") {
                try? FileManager.default.removeItem(at: fileURL)
                reloadSavedSkins()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - Actions
    private func applySkinFromCatalog(_ item: CatalogSkinItem) {
        Task {
            do {
                let (skin, _, data) = try await SkinDownloaderService.shared.downloadSkinByUsername(item.username)
                await MainActor.run {
                    onApplySkin(skin, item.name)
                    SkinStorageManager.shared.saveSkin(data: data, name: item.name)
                    reloadSavedSkins()
                    showToast("\(item.name) 스킨을 착용했습니다!")
                }
            } catch {
                await MainActor.run {
                    showToast("스킨 다운로드 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    private func saveSkinToDownloads(_ item: CatalogSkinItem) {
        Task {
            do {
                let (_, _, data) = try await SkinDownloaderService.shared.downloadSkinByUsername(item.username)
                await MainActor.run {
                    exportToDownloads(data: data, filename: "\(item.name).png")
                }
            } catch {
                await MainActor.run {
                    showToast("다운로드 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    private func performUsernameSearch() {
        let name = searchUsername.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isSearching = true
        searchError = nil

        Task {
            do {
                let (skin, image, data) = try await SkinDownloaderService.shared.downloadSkinByUsername(name)
                await MainActor.run {
                    self.searchResultSkin = skin
                    self.searchResultImage = image
                    self.searchResultData = data
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.searchError = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }

    private func downloadFromCustomURL() {
        let urlStr = customURLString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: urlStr) else {
            urlError = "올바른 URL 주소를 입력하세요."
            return
        }

        isDownloadingURL = true
        urlError = nil

        Task {
            do {
                let (skin, _, data) = try await SkinDownloaderService.shared.downloadSkin(from: url)
                let skinName = url.deletingPathExtension().lastPathComponent
                await MainActor.run {
                    onApplySkin(skin, skinName)
                    SkinStorageManager.shared.saveSkin(data: data, name: skinName)
                    reloadSavedSkins()
                    showToast("웹 URL에서 스킨을 성공적으로 적용했습니다!")
                    isDownloadingURL = false
                }
            } catch {
                await MainActor.run {
                    self.urlError = error.localizedDescription
                    self.isDownloadingURL = false
                }
            }
        }
    }

    private func reloadSavedSkins() {
        savedSkins = SkinStorageManager.shared.listSavedSkins()
    }

    private func exportToDownloads(data: Data, filename: String) {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let dest = downloads.appendingPathComponent(filename)
        do {
            try data.write(to: dest)
            showToast("다운로드 폴더에 저장되었습니다: \(filename)")
        } catch {
            showToast("파일 저장 실패: \(error.localizedDescription)")
        }
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if toastMessage == msg {
                toastMessage = nil
            }
        }
    }
}
