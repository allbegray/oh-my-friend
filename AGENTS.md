이 문서는 AI 에이전트의 작업 지침, 프로젝트 아키텍처 컨텍스트, 빌드 및 실행 기록을 관리합니다.

# 프로젝트 요약
Oh My Friend는 AppKit과 SceneKit, SwiftUI를 기반으로 제작된 macOS 네이티브 데스크톱 컴패니언 애플리케이션입니다. 3D 마인크래프트 복셀 캐릭터가 화면 위에서 열려 있는 창문과 Dock을 발판 삼아 자율적으로 배회하고, 마우스 커서를 응시하며, 온라인 스킨 갤러리 및 Mojang API를 통한 실시간 스킨 다운로드를 지원합니다.

## 빌드/테스트 방법

```bash
# 빠른 빌드 및 실행
./scripts/run.sh

# 릴리스 번들 패키징 (OhMyFriend.app 생성)
./scripts/build_app.sh

# 응용 프로그램 폴더 설치
./scripts/install.sh

# Swift Package Manager 직접 빌드
swift build
swift build -c release

# 스모크 테스트 (백그라운드 실행 후 정상 종료 확인)
./OhMyFriend.app/Contents/MacOS/OhMyFriend &
PID=$!
sleep 2
kill $PID
```

## 에이전트 행동 지침
- **필수 문서 6종 유지**: `AGENTS.md`, `BACKLOG.md`, `CHANGELOG.md`, `README.md`, `SECURITY.md`, `SOLUTION.md`는 루트 디렉터리에 상시 유지하며, 루트에는 이 6종 `.md`만 허용합니다.
- **한국어 작성 원칙**: 모든 문서 작성과 git 커밋 메시지는 한국어로 작성합니다(코드 및 기술 용어는 영문 허용).
- **작업 전후 동기화**: 작업 시작 시 `AGENTS.md`를 최우선으로 확인하고, 코드 변경 완료 후 `graphify --update` 명령으로 지식 그래프를 갱신하며 `AGENTS.md` 실행 기록에 즉시 반영합니다.
- **빌드 안전성 보장**: `Package.swift`는 다양한 CommandLineTools 환경을 고려해 `swift-tools-version: 5.7` 수준의 높은 하위 호환성을 유지하고, `scripts/build_app.sh`에는 `swiftc` 직접 컴파일 Fallback을 유지합니다.

## 서브시스템 구조

```
Sources/OhMyFriend/
├── main.swift                          # 진입점 및 NSApplication 라이프사이클 관리 (.accessory 모드)
├── AppController.swift                 # 60fps 메인 루프 조정자, 메뉴바 상태 아이콘 및 컨텍스트 메뉴 총괄
├── CharacterWindow.swift               # 투명 무테 플로팅 패널 (NSPanel, Space 전환 지원)
├── CharacterView.swift                 # SceneKit 3D 뷰, 마우스 드래그/던지기, 파일 드롭 처리
├── MinecraftCharacterNode.swift        # 마인크래프트 3D 복셀 모델 노드 계층 및 애니메이션 컨트롤러
├── SkinTexture.swift                   # 64x64/64x32 텍스처 파서, 기본 내장 스킨 3종 픽셀아트 생성기
├── PhysicsAndEnvironment.swift         # CGWindowList 창문 감지, Dock 영역 분석, 중력/낙하 물리 엔진
├── CharacterBehaviorController.swift   # 자율 행동 FSM (배회, 시선 추적, 창문 걸터앉기, Dock 노크)
├── SkinCatalogManager.swift            # 추천 스킨 카탈로그 데이터 및 로컬 보관함(~/Library/.../Skins) 관리자
├── SkinDownloaderService.swift         # Mojang/Minotar/Crafatar API 비동기 다운로더 및 URL 검증기
├── SkinGalleryView.swift               # SwiftUI 기반 4개 탭 스킨 갤러리 UI
└── SkinGalleryWindowController.swift   # 스킨 갤러리 전용 NSWindow 컨트롤러
```

- **렌더링 & 애니메이션 파이프라인**: `CharacterView` 내부의 `SCNScene`에서 `MinecraftCharacterNode`가 관절 피벗(목, 어깨, 골반)을 기반으로 회전 및 위치를 실시간 보간합니다.
- **물리 & 윈도우 추적**: `ScreenEnvironment`가 0.5초 주기로 활성 앱 윈도우 타이틀바의 Cocoa 좌표계 상단을 스캔하여 발판(`Platform`) 목록을 갱신하고, `PhysicsEngine`이 중력 가속도와 착지 판정을 처리합니다.
- **스킨 파이프라인**: 로컬 파일, 기본 내장 픽셀아트 생성기, 온라인 다운로더(Mojang/Minotar)를 통해 64x64 PNG 데이터를 확보하고, 각 면(Front, Right, Back, Left, Top, Bottom)을 슬라이스하여 Nearest-neighbor 재질로 큐브에 매핑합니다.

## 실행 기록

### 2026-09-09
- **초기 프로젝트 생성**: Swift Package Manager 프로젝트 구조 생성 및 `Package.swift` 구성.
- **3D 복셀 모델 및 텍스처 시스템 개발**: `SkinTexture.swift`, `MinecraftCharacterNode.swift` 구현 (Steve, Alex, Zombie 절차적 스킨 생성기 포함).
- **물리 엔진 및 환경 스캐너 개발**: `PhysicsAndEnvironment.swift` 구현 (창문 타이틀바 감지, Dock 높이 계산, 중력 및 착지/낙하 물리).
- **자율 행동 AI 및 인터랙션 개발**: `CharacterBehaviorController.swift` 구현 (실시간 커서 시선 추적, 창문 걸터앉기, Dock 노크 모션).
- **UI 및 앱 컨트롤러 개발**: 투명 `NSPanel` 기반 `CharacterWindow`, 메뉴바 트레이 상태 아이콘 및 컨텍스트 메뉴 구현.
- **스킨 갤러리 & 다운로더 기능 추가**: Mojang/Minotar API 연동 `SkinDownloaderService`, 추천 카탈로그 `SkinCatalogManager`, SwiftUI 기반 `SkinGalleryView` 및 전용 윈도우 컨트롤러 구현.
- **빌드 호환성 개선**: CommandLineTools 매니페스트 링커 이슈 해결을 위해 `swift-tools-version: 5.7` 적용 및 `scripts/build_app.sh`에 `swiftc` 자동 Fallback 안전장치 추가.
- **거버넌스 문서화 및 지식 그래프 구축**: 필수 문서 6종(AGENTS.md, BACKLOG.md, CHANGELOG.md, README.md, SECURITY.md, SOLUTION.md) 생성 및 `graphify` 초기 그래프 빌드 완료.
- **Laby.net 및 웹페이지 스킨 자동 추출 지원**: `SkinDownloaderService`에 Laby.net(`laby.net/skins/<hash>`), 프로필(`laby.net/@user`), NameMC 등의 웹페이지 URL 입력 시 내부 Mojang 텍스처를 자동 추출하는 지능형 파서 추가. `SkinGalleryView` 추천 사이트에 Laby.net 바로가기 버튼 추가.
- **Laby.net Cloudflare 403 대응 및 다이렉트 텍스처 CDN 변환**: Laby.net HTML 페이지 요청 시 발생하는 Cloudflare 봇 차단(403)을 우회하기 위해, URL 경로의 32자리 해시를 추출하여 공개 CDN인 `https://laby.net/texture/<hash>.png`로 다이렉트 변환 다운로드하도록 개선. 32자리 해시 단독 입력 및 프로토콜 생략 입력에 대한 자동 보정 로직 추가.
- **Laby.net Cloudflare TLS 지문 불일치 403 버그 수정**: 크롬 User-Agent 위조로 인해 Cloudflare의 TLS 지문(JA3/JA4) 검사에서 403 Forbidden이 반환되던 문제를 네이티브 `OhMyFriend/1.0 (Macintosh; Mac OS X)` 헤더로 변경하여 완벽 해결. `scripts/run.sh`에 실행 중인 구버전 프로세스 자동 종료 및 새 버전 재시작 로직 추가.
- **캐릭터 크기 조절 세분화 및 수기 입력 기능 구현**: 9단계 세분화 프리셋(50%~250%) 지원, 메뉴바 "✏️ 크기 직접 입력... (Cmd + S)" 다이얼로그(`NSAlert`) 추가, 스킨 갤러리 상단 헤더에 실시간 슬라이더 및 퍼센트 수기 입력 텍스트 필드 구현.
- **graphify-out 디렉토리 git 추적 제외**: 로컬 지식 그래프 캐시 및 결과물인 `graphify-out/`을 `.gitignore`에 등록하고 git 추적에서 제외.
