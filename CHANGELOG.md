이 문서는 Oh My Friend 프로젝트의 버전별 변경 사항 및 릴리스 이력을 관리합니다.

# 변경 이력

## [v0.1.1] - 2026-09-09

### 추가
- Laby.net(laby.net/skins) 스킨 사이트 지원: 스킨 상세 페이지 주소(`https://laby.net/skins/<hash>`) 및 프로필 주소(`https://laby.net/@username`) 입력 지원.
- 스킨 갤러리 추천 사이트 목록에 Laby.net 바로가기 버튼 추가.

### 수정
- Laby.net 웹페이지 HTML 요청 시 Cloudflare 403 Forbidden 오류를 해결하기 위해, URL에서 32자리 해시를 추출하여 `https://laby.net/texture/<hash>.png` 공개 CDN 주소로 다이렉트 변환 다운로드하도록 개선.
- User-Agent 헤더를 네이티브 `OhMyFriend/1.0 (Macintosh; Mac OS X)`로 변경하여 Cloudflare의 TLS 지문(JA3/JA4) 불일치 차단 버그를 해결.
- `scripts/run.sh`에 기존 실행 중인 이전 버전 앱을 자동으로 종료하고 새 버전으로 재실행하도록 개선.

## [v0.1.0] - 2026-09-09

### 추가
- 마인크래프트 규격(머리 8x8x8, 몸통 8x12x4, 팔/다리 4x12x4) 3D 복셀 모델 및 텍스처 렌더러 구현.
- 기본 내장 스킨 3종(스마트 스티브, 알렉스, 귀여운 좀비)의 절차적 픽셀아트 생성기 구현.
- AppKit 투명 무테 플로팅 윈도우(`CharacterWindow`) 및 SceneKit 기반 뷰(`CharacterView`) 구현.
- `CGWindowList` 기반 활성 앱 윈도우 타이틀바 감지 및 Dock 영역 자동 분석 물리 플랫폼 엔진 구현.
- 자율 행동 AI(FSM): 마우스 커서 시선 추적, 창문 타이틀바 배회 및 모서리 걸터앉아 다리 흔들기, Dock 아이콘 툭툭 건드리기 모션 구현.
- 마우스 드래그 & 던지기 물리 관성 및 파일 드래그 앤 드롭 스킨 변경 기능 추가.
- macOS 상단 메뉴바 트레이 상태 아이콘(8-bit 스티브 얼굴) 및 실시간 상태 표시, 스킨/행동모드/크기 조절 컨텍스트 메뉴 구현.
- 마인크래프트 온라인 스킨 갤러리 & 다운로더 윈도우(SwiftUI) 추가 (인기 스킨 프리셋, 정품 닉네임 실시간 검색, 웹 이미지 직링크 다운로드, 로컬 보관함).
- 자동 빌드 및 `/Applications` 설치 스크립트(`scripts/build_app.sh`, `scripts/install.sh`, `scripts/run.sh`) 추가.

### 수정
- macOS CommandLineTools 링커 환경 차이로 인한 SPM 매니페스트 링크 에러를 해결하기 위해 `Package.swift` 도구 버전을 5.7로 조정하고, `scripts/build_app.sh`에 `swiftc` 직접 컴파일 Fallback 안전장치 적용.
