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
├── BlockBreakOverlayWindow.swift       # 곡괭이 공격: 대상 창 크랙(10단계, 번개형 점진 확산)→블록 파편 연출 오버레이
├── SkinCatalogManager.swift            # 추천 스킨 카탈로그 데이터 및 로컬 보관함(~/Library/.../Skins) 관리자
├── SkinDownloaderService.swift         # Mojang/Minotar/Crafatar API 비동기 다운로더 및 URL 검증기
├── SkinGalleryView.swift               # SwiftUI 기반 4개 탭 스킨 갤러리 UI
└── SkinGalleryWindowController.swift   # 스킨 갤러리 전용 NSWindow 컨트롤러
```

- **렌더링 & 애니메이션 파이프라인**: `CharacterView` 내부의 `SCNScene`에서 `MinecraftCharacterNode`가 관절 피벗(목, 어깨, 골반)을 기반으로 회전 및 위치를 실시간 보간합니다.
- **물리 & 윈도우 추적**: `ScreenEnvironment`가 0.5초 주기로 활성 앱 윈도우 타이틀바의 Cocoa 좌표계 상단을 스캔하여 발판(`Platform`) 목록을 갱신하고, `PhysicsEngine`이 중력 가속도와 착지 판정을 처리합니다.
- **스킨 파이프라인**: 로컬 파일, 기본 내장 픽셀아트 생성기, 온라인 다운로더(Mojang/Minotar)를 통해 64x64 PNG 데이터를 확보하고, 각 면(Front, Right, Back, Left, Top, Bottom)을 슬라이스하여 Nearest-neighbor 재질로 큐브에 매핑합니다.

## 실행 기록

### 2026-09-10
- **곡괭이 공격 크래시 수정**: 크랙 1단계 렌더 시 `drawBolt`에서 `pts[1...0]` 무효 슬라이스로 앱이 즉시 종료되던 SIGTRAP 크래시 수정(노출 길이가 첫 세그먼트보다 짧은 경우 가드). 1~10단계 전 구간 드라이버 렌더로 검증.
- **화면 기록 권한 프롬프트 제거**: 파편 텍스처용 대상 창 실사 스냅샷(`CGWindowListCreateImage`) 캡처를 삭제하고 시스템 라이트/다크 톤 팔레트 전용으로 단순화. `ScreenEnvironment.windowSnapshotCGImage` API 제거.
- **백색 플래시 이펙트 제거**: 파편 폭발 직전 하얀 창 화면이 노출되는 것처럼 보이던 연출 제거. '앱 창 부수기' 메뉴 단축키(Cmd+B)도 제거(오입력으로 사용 중 앱이 종료되는 것 방지, 메뉴 선택 시에만 발동).
- **파편 격자 창 크기 정합**: `Int(width/cell)` 내림으로 오른쪽·위 가장자리에 남던 빈 틈을 제거하고 창 폭/높이를 셀 수로 나눠 정확히 타일링. 대기 중인 파편도 제자리에 렌더링하도록 수정해, 부서지기 전 0.06초 동안 창이 블록 격자로 바뀐 모습이 창 영역과 일치(가장자리 커버리지 0.93~0.94, 창 밖 유출 0.00 측정).
- **파편 비산 범위·힘 강화**: 오버레이 패널 여백이 곧 드로잉 클리핑 경계임을 반영해 좌우 340 / 상단 420 / 하단 640pt까지 확장하고 초기 속도·회전을 상향(측정: t=0.6초 시점 창 밖 좌 284 / 우 308 / 상 271pt 비산, 좌우 총 폭 1452pt ≈ 창 폭의 1.7배).

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
- **화면 가장자리 도달 시 제자리걸음 방지 및 자연스러운 전이(쉬기/뒤돌기) FSM 개선**: 물리 엔진 좌표 클램프 마진과 행동 감지 마진을 35pt로 일치시켜 화면 끝 도착 즉시 걷기를 멈추고 45% 확률로 앉아서 쉬기(`.sit`), 40% 확률로 몸을 돌려 화면 안쪽으로 걸어가기, 15% 둘러보기로 상태 전환. 이동 정체(Stuck) 감지 안전장치 추가.
- **인터랙션 대규모 확장 (v0.2.0)**: 3D 손 아이템(곡괭이/검/사과/횃불), 더블 클릭 360도 공중제비(Backflip), 마우스 근접 손흔들기(Wave), 클릭 하트(❤️), 마인크래프트 Shift 쉬프트 댄스, 블록 설치/채굴 모션, 45초 유휴 시 수면(Sleep & Zzz) 및 기상(❗), 레트로 사운드 매니저(`SoundAndEffectsManager`) 구현.
- **곡괭이 앱 창 부수기 기능 추가**: 캐릭터가 서 있는 다른 앱의 창을 3D 복셀 곡괭이(나무 자루+돌 머리)로 내리치는 공격 상태(FSM `.attack`, 휘두르는 동안 오른팔 채굴 모션) 구현. 휘두르는 2.4초 동안 대상 창 위 투명 오버레이(`BlockBreakOverlayWindow.swift`)에 5단계 크랙이 진행되고, 마지막에 백색 플래시와 함께 창 전체가 복셀 블록 파편으로 부서지며 대상 앱이 정상 종료(`NSRunningApplication.terminate`)된다. 메뉴바/우클릭 메뉴 '⛏️ 앱 창 부수기'(Cmd+B)로 수동 발동, 캐릭터가 다른 앱 창 플랫폼 위에 있을 때만 활성화. 공격 중 드래그하면 연출 중단. 창 플랫폼에 소유 PID 기록 추가 및 `ScreenEnvironment.windowCocoaFrame(windowID:)` 조회 API 추가. **1차 리뷰 후 연출 개선**: 국소(공격 지점 아래) 균열을 버리고 창 중앙에서 번개 모양으로 바깥까지 점진 확산하는 크랙으로 교체(중점 변위법으로 생성한 크랙 트리, 10단계 destroy 스테이지, 고정 2초 경과 기반 progress에 따라 노출 길이 성장, 어두운 코어+밝은 테두리 2패스 드로잉). 파편 색을 단색 팔레트 대신 대상 창 실사 스냅샷 블록별 샘플링(화면 기록 권한 없으면 시스템 라이트/다크 톤 폴백)으로 교체.
