# Oh My Friend (오마이프렌드) 🎮⛏️

> **macOS Desktop Companion in Minecraft Style**  
> 화면 위를 스스로 돌아다니고, 창문에 걸터앉거나, 마우스 커서를 따라보고, Dock을 툭툭 건드리는 마인크래프트 3D 복셀 친구!

---

## ✨ Features

- **마인크래프트 3D 복셀 캐릭터**:
  - 표준 마인크래프트 규격 복셀 모델 (Head 8x8x8, Torso 8x12x4, Arms 4x12x4, Legs 4x12x4)
  - 관절 피벗(Pivot) 기반 3D 애니메이션 (걷기, 숨쉬기, 걸터앉기, 블록 캐기/펀치, 낙하, 발버둥)
  - `Nearest-neighbor` 픽셀 보간으로 레트로 픽셀아트 텍스처 표현
  - **기본 스킨 3종 내장**: Steve(스마트 스티브), Alex(알렉스), Zombie(귀여운 좀비)
  - **커스텀 스킨 지원**: 64x64 마인크래프트 스킨 PNG 파일을 캐릭터에 드래그 앤 드롭하여 즉시 변경 가능

- **스마트한 물리 엔진 & 화면 인식**:
  - `CGWindowList`를 이용한 열려 있는 애플리케이션 윈도우 타이틀바 실시간 감지
  - `NSScreen.visibleFrame`을 통한 Dock 위치 인식 및 바닥 플랫폼 생성
  - 중력 가속도, 창문 닫힘/이동 시 자동 낙하 물리 적용

- **자율 행동 AI (Autonomous FSM)**:
  - **커서 시선 추적**: 마우스 커서의 실시간 위치를 감지하여 고개가 부드럽게 커서를 응시
  - **창문에 걸터앉기**: 윈도우 타이틀바 위를 걷다가 끝에 다다르면 다리를 내리고 걸터앉아 다리를 살랑살랑 흔듦
  - **Dock 아이콘 툭툭 건드리기**: Dock 위를 산책하다가 아래를 내려다보며 마인크래프트 펀치 모션으로 Dock 아이콘을 툭툭 침
  - **마우스 드래그 & 던지기**: 캐릭터를 마우스로 잡고 들어올리면 공중에 매달려 버둥버둥거리며, 놓으면 마우스 이동 속도에 따라 관성 낙하

- **네이티브 메뉴바 & 컨텍스트 메뉴**:
  - macOS 상단 메뉴바의 8-bit 스티브 얼굴 아이콘
  - 실시간 캐릭터 상태 표시 (예: "Safari 창에 걸터앉아 쉬는 중", "Dock 아이콘 건드리기 ⛏️")
  - 스킨 선택, 행동 모드(자유 배회, 커서 따라오기, 멍때리기), 크기 조절(70%, 100%, 150%) 지원

---

## 🚀 Getting Started

### 요구 사항
- macOS 13.0 (Ventura) 이상
- Swift 5.9 이상 (Xcode Command Line Tools)

### 실행 방법

1. **저장소 클론**:
   ```bash
   git clone https://github.com/allbegray/oh-my-friend.git
   cd oh-my-friend
   ```

2. **빌드 및 실행**:
   ```bash
   ./scripts/run.sh
   ```

3. **직접 빌드만 수행**:
   ```bash
   ./scripts/build_app.sh
   open OhMyFriend.app
   ```

---

## 🛠️ Tech Stack

- **Language**: Swift 6 (Swift Package Manager)
- **Frameworks**:
  - **AppKit**: 투명 `NSPanel`, `NSStatusBar`, 드래그 앤 드롭, 마우스 이벤트
  - **SceneKit**: 3D 복셀 모델링, 계층 노드 조인트, 조명, 텍스처 매핑
  - **CoreGraphics**: 화면 윈도우 좌표 변환, 플랫폼 감지
