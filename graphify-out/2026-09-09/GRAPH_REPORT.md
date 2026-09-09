# Graph Report - oh-my-friend  (2026-09-09)

## Corpus Check
- 22 files · ~12,693 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 308 nodes · 522 edges · 19 communities (15 shown, 4 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 26 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d86d3ef8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- AppController
- SkinGalleryView
- PhysicsEngine
- SkinTexture
- CharacterWindow
- SkinDownloadError
- AppKit
- Oh My Friend: 마인크래프트 스타일의 macOS 데스크톱 컴패니언 🎮⛏️
- CharacterView
- Package.swift
- build_app.sh
- install.sh
- run.sh
- [CommandLineTools와 SPM 매니페스트 링커 불일치 오류]
- SkinGalleryWindowController
- 프로젝트 요약
- 보안 정책
- 백로그
- [v0.1.0] - 2026-09-09

## God Nodes (most connected - your core abstractions)
1. `AppController` - 39 edges
2. `SkinGalleryView` - 28 edges
3. `CharacterView` - 22 edges
4. `SkinTexture` - 22 edges
5. `PhysicsEngine` - 16 edges
6. `MinecraftCharacterNode` - 13 edges
7. `Platform` - 13 edges
8. `CharacterBehaviorController` - 12 edges
9. `State` - 12 edges
10. `CharacterWindow` - 12 edges

## Surprising Connections (you probably didn't know these)
- `AppController` --calls--> `CharacterBehaviorController`  [INFERRED]
  Sources/OhMyFriend/AppController.swift → Sources/OhMyFriend/CharacterBehaviorController.swift
- `CharacterView` --calls--> `MinecraftCharacterNode`  [INFERRED]
  Sources/OhMyFriend/CharacterView.swift → Sources/OhMyFriend/MinecraftCharacterNode.swift
- `AppController` --implements--> `CharacterViewDelegate`  [EXTRACTED]
  Sources/OhMyFriend/AppController.swift → Sources/OhMyFriend/CharacterView.swift
- `AppController` --references--> `CharacterWindow`  [EXTRACTED]
  Sources/OhMyFriend/AppController.swift → Sources/OhMyFriend/CharacterWindow.swift
- `AppController` --references--> `PhysicsEngine`  [EXTRACTED]
  Sources/OhMyFriend/AppController.swift → Sources/OhMyFriend/PhysicsAndEnvironment.swift

## Import Cycles
- None detected.

## Communities (19 total, 4 thin omitted)

### Community 0 - "AppController"
Cohesion: 0.08
Nodes (19): Notification, NSApplication, NSApplicationDelegate, NSMenu, NSMenuDelegate, NSMenuItem, NSObject, NSStatusItem (+11 more)

### Community 1 - "SkinGalleryView"
Cohesion: 0.11
Nodes (23): Hashable, Identifiable, CatalogSkinItem, SkinCatalogManager, SkinStorageManager, Data, String, URL (+15 more)

### Community 2 - "PhysicsEngine"
Cohesion: 0.08
Nodes (32): CGWindowID, Equatable, CharacterBehaviorController, State, dragged, fall, idle, landedCrouch (+24 more)

### Community 3 - "SkinTexture"
Cohesion: 0.09
Nodes (20): CGImage, SCNMaterial, SCNNode, NSCoder, MinecraftCharacterNode, Bool, CGFloat, NSCoder (+12 more)

### Community 4 - "CharacterWindow"
Cohesion: 0.13
Nodes (11): NSPanel, NSRect, pid_t, CharacterWindow, .canBecomeKey, .canBecomeMain, Bool, CGFloat (+3 more)

### Community 5 - "SkinDownloadError"
Cohesion: 0.14
Nodes (15): Foundation, LocalizedError, SkinDownloadError, .errorDescription, invalidSkinImage, invalidURL, invalidUsername, networkError (+7 more)

### Community 6 - "AppKit"
Cohesion: 0.12
Nodes (17): AppKit, CaseIterable, CoreGraphics, SceneKit, BehaviorMode, autonomous, chill, followCursor (+9 more)

### Community 7 - "Oh My Friend: 마인크래프트 스타일의 macOS 데스크톱 컴패니언 🎮⛏️"
Cohesion: 0.17
Nodes (11): 1. 3D 마인크래프트 복셀 캐릭터 & 자율 AI, 1. 요구 사항, 2. 온라인 스킨 갤러리 & 다운로더 (`Cmd + G`), 2. 저장소 클론 및 빠른 실행, 3. macOS 시스템에 설치하기, 3. 네이티브 상단 메뉴바 & 컨텍스트 메뉴, Oh My Friend: 마인크래프트 스타일의 macOS 데스크톱 컴패니언 🎮⛏️, 라이선스 (+3 more)

### Community 8 - "CharacterView"
Cohesion: 0.23
Nodes (10): AnyObject, NSDraggingInfo, NSDragOperation, SCNView, CharacterView, CharacterViewDelegate, Bool, CGPoint (+2 more)

### Community 13 - "[CommandLineTools와 SPM 매니페스트 링커 불일치 오류]"
Cohesion: 0.12
Nodes (16): [CommandLineTools와 SPM 매니페스트 링커 불일치 오류], [Laby.net 스킨 페이지 URL 다운로드 시 Cloudflare 403 Forbidden 오류], [macOS SceneKit SCNVector3 좌표 컴포넌트 타입 불일치], 문제 해결 지식, 원인, 원인, 원인, 재발 방지 (+8 more)

### Community 14 - "SkinGalleryWindowController"
Cohesion: 0.38
Nodes (5): NSWindowController, SkinGalleryWindowController, NSCoder, String, Void

### Community 15 - "프로젝트 요약"
Cohesion: 0.29
Nodes (6): 2026-09-09, 빌드/테스트 방법, 서브시스템 구조, 실행 기록, 에이전트 행동 지침, 프로젝트 요약

### Community 16 - "보안 정책"
Cohesion: 0.33
Nodes (5): 보안 정책, 비밀 관리, 인증/인가, 취약점 보고, 코드 작성 시 보안 규칙

### Community 17 - "백로그"
Cohesion: 0.40
Nodes (4): 낮음 (L), 높음 (H), 백로그, 중간 (M)

### Community 18 - "[v0.1.0] - 2026-09-09"
Cohesion: 0.25
Nodes (7): [v0.1.0] - 2026-09-09, [v0.1.1] - 2026-09-09, 변경 이력, 수정, 수정, 추가, 추가

## Knowledge Gaps
- **75 isolated node(s):** `PackageDescription`, `autonomous`, `followCursor`, `chill`, `idle` (+70 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SkinTexture` connect `SkinTexture` to `AppController`, `SkinGalleryView`, `CharacterWindow`, `SkinDownloadError`, `AppKit`, `SkinGalleryWindowController`?**
  _High betweenness centrality (0.203) - this node is a cross-community bridge._
- **Why does `AppController` connect `AppController` to `CharacterView`, `PhysicsEngine`, `CharacterWindow`, `AppKit`?**
  _High betweenness centrality (0.196) - this node is a cross-community bridge._
- **Why does `SkinGalleryView` connect `SkinGalleryView` to `SkinTexture`, `AppKit`, `SkinGalleryWindowController`?**
  _High betweenness centrality (0.106) - this node is a cross-community bridge._
- **What connects `PackageDescription`, `autonomous`, `followCursor` to the rest of the system?**
  _75 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `AppController` be split into smaller, more focused modules?**
  _Cohesion score 0.07682926829268293 - nodes in this community are weakly interconnected._
- **Should `SkinGalleryView` be split into smaller, more focused modules?**
  _Cohesion score 0.1106612685560054 - nodes in this community are weakly interconnected._
- **Should `PhysicsEngine` be split into smaller, more focused modules?**
  _Cohesion score 0.07641196013289037 - nodes in this community are weakly interconnected._