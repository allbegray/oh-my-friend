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
├── BlockBreakOverlayWindow.swift       # TNT 폭파: 도화선 점멸→폭발 섬광·연기·블록 파편 오버레이
├── TNTEntityWindow.swift               # 창 표면에 놓인 TNT 블록 엔티티(픽셀아트 + 도화선 점멸)
├── LadderOverlayWindow.swift           # 사다리 등반: 창문 높이만큼만 생성되는 레일 2개 + 가로대 오버레이
├── SkinCatalogManager.swift            # 추천 스킨 카탈로그 데이터 및 로컬 보관함(~/Library/.../Skins) 관리자
├── SkinDownloaderService.swift         # Mojang/Minotar/Crafatar API 비동기 다운로더 및 URL 검증기
├── SkinGalleryView.swift               # SwiftUI 기반 4개 탭 스킨 갤러리 UI
├── SkinGalleryWindowController.swift   # 스킨 갤러리 전용 NSWindow 컨트롤러
├── TridentEntityWindow.swift           # 삼지창 투척체: 포물선 비행→회전하며 손으로 복귀하는 충성 연출
├── JukeboxEntityWindow.swift           # 바닥 설치형 픽셀아트 주크박스(8초 재생 후 자동 정리)
├── ChestEntityWindow.swift             # 클릭 시 뚜껑 열림 + 전리품 텍스트 방출하는 1회용 보물 상자
├── SlimeWindow.swift                   # 대/중/소 3단계 분열 슬라임(스쿼시 점프 이동, 클릭 타격 분열)
├── NetherPortalOverlayWindow.swift     # 흑요석 틀 + 보라 소용돌이 지옥문 오버레이
├── DayNightCycleManager.swift          # 실제 시간 기반 낮밤 판정(자동/낮고정/밤고정) 및 야간 스폰 가중치
├── CropEntityWindow.swift              # 밀 농사: 4단계 성장 작물(25초/단계), 성숙 클릭 수확
├── WeatherManager.swift                # 비·뇌우 랜덤 전환(150~300초) 및 번개 타이머
├── RainOverlayWindow.swift             # 빗줄기 + 번개 섬광·볼트 오버레이
├── BeeEntityWindow.swift               # 벌 3마리 추적 + 30초 꿀 생산 벌집
├── BrewStandWindow.swift               # 양조기 + 3색 물약병(신속/투명/힘 양조)
├── FoxWindow.swift                     # 밤 여우(급속 지그재그 이동, 아이템 낚아채기·14초 추격전)
├── GoatWindow.swift                    # 염소(풀뜯기→조준→돌진 3단 AI, 빈 양동이 우유 짜기)
└── Advancements.swift                  # 발전 과제 16종·해금 토스트·체크리스트 창(UserDefaults 영속)
```

- **렌더링 & 애니메이션 파이프라인**: `CharacterView` 내부의 `SCNScene`에서 `MinecraftCharacterNode`가 관절 피벗(목, 어깨, 골반)을 기반으로 회전 및 위치를 실시간 보간합니다.
- **물리 & 윈도우 추적**: `ScreenEnvironment`가 0.5초 주기로 활성 앱 윈도우 타이틀바의 Cocoa 좌표계 상단을 스캔하여 발판(`Platform`) 목록을 갱신하고, `PhysicsEngine`이 중력 가속도와 착지 판정을 처리합니다.
- **등반 연출 파이프라인**: `CharacterBehaviorController`가 매 프레임 등반 스냅샷(사다리 사각형 + 진행률)을 만들고, `AppController.syncLadderOverlay()`가 `LadderOverlayWindow`를 생성·갱신·정리합니다. 사다리는 창문 면을 따라(내려갈 때는 창문 위쪽 끝→창 아래 끝, 올라갈 때는 놓인 자리→창문 위쪽 끝) 생성되어 화면 좌표계에 고정되고(창이 움직이면 따라 이동), 캐릭터 창보다 한 단계 아래 레벨(`floating - 1`)에 그려집니다.
- **스킨 파이프라인**: 로컬 파일, 기본 내장 픽셀아트 생성기, 온라인 다운로더(Mojang/Minotar)를 통해 64x64 PNG 데이터를 확보하고, 각 면(Front, Right, Back, Left, Top, Bottom)을 슬라이스하여 Nearest-neighbor 재질로 큐브에 매핑합니다.

## 실행 기록

### 2026-09-10
- **[업적 시스템] 발전 과제 16종 도입**: `Advancements.swift`(과제 정의·해금·토스트 큐·체크리스트 창, UserDefaults 영속). 채굴·몹 4종·길들이기 2종·수확·낚시·양조·인챈트·거래·지옥문·승마·친구·밤스킵 16곳 훅 연결, 달성 시 우상단 토스트 + 차임. 메뉴 "🏆 발전 과제 (n/16)" 추가. 검증: `swift build` 통과, 번들 생성 및 4초 실행 스모크 테스트.
- **[고증 추가 5종 3차] 양조·거래·여우·수레·염소 구축**: `BrewStandWindow.swift`(신속/투명/힘 물약 양조·시간제 효과), 에메랄드 재화 + NSAlert 주민 거래(검 3/사과 2/토템 5), `FoxWindow.swift`(밤 여우 낚아채기·14초 추격 회수전), Dock 광산 수레 10초 왕복 질주, `GoatWindow.swift`(3단 돌진 AI·빈 양동이 우유 짜기). 메뉴 5종 추가. 검증: `swift build` 통과, 번들 생성 및 4초 실행 스모크 테스트.
- **[고증 추가 5종 2차] 말·인챈트·디펜스·풍선·멀티캐릭터 구축**: `PetKind.horse` + 3D 복셀 말(`buildHorseModel`) + 야생마 황금사과 길들이기 + 14초 260pt/s 승마 질주, `EnchantTableWindow.swift`(XP 10 날카로움/효율 강화·광택·데미지 반영, 크리퍼+5/스켈레톤+5/엔더맨+8/슬라임+3), 밤 웨이브 디펜스전(격퇴 카운트·클리어 보너스), `HeldItem.balloon` + `PhysicsEngine.isSlowFalling`(-60pt/s·퐁신 착지), **[L1] 멀티 캐릭터**(최대 2기 독립 FSM·물리·델리게이트 라우팅 `triple(for:)`). 메뉴 6종 추가. 검증: `swift build` 통과, 번들 생성 및 4초 실행 스모크 테스트. 백로그 전량 완료.
- **[고증 추가 5종] 농사·길들이기·날씨·밤스킵·벌꿀 구축**: `CropEntityWindow.swift`(25초/단계 4단계 성장·클릭 수확), 야생 늑대 배회 + 뼈다귀 길들이기 펫 편입, `WeatherManager.swift`(150~300초 비·뇌우 전환) + `RainOverlayWindow.swift`(빗줄기·번개 섬광·볼트) + 뇌우 충전 크리퍼(폭발 1.6배), 밤 전원 6초 수면 시 15분 아침 스킵(`skipToMorning` + `wakeUpIfSleeping`), `BeeEntityWindow.swift`(벌 3마리 꽃 추적 + 30초 꿀 벌집). `HeldItem.flower` 추가, 메뉴 3종(밀 심기/야생 늑대/벌집) + "🌧️ 날씨 모드" 토글 추가. 검증: `swift build` 통과, 번들 생성 및 4초 실행 스모크 테스트.
- **[H2/H3/H4/M1/M2/M3/M4/L2/L3] 백로그 9종(L1 제외) 일괄 구축**: `TridentEntityWindow.swift`, `JukeboxEntityWindow.swift`, `ChestEntityWindow.swift`, `SlimeWindow.swift`, `NetherPortalOverlayWindow.swift`, `DayNightCycleManager.swift` 신규 구현. 삼지창 충성 복귀 투척 + 웅크리기 급류 추진, 주크박스 8초 재생 + 캐릭터/펫 리듬 댄스, 실제 시간 낮밤(18시~06시 야간 횃불 자동 점등 + 몬스터 1.5배 출현), 클릭 오픈 보물 상자, 왼손 토템 폭발 부활, 3단계 분열 슬라임(최대 8마리), 밀 유혹 + 2회 먹이 아기 펫 탄생·60초 성장, 우유 60초 디버프 정화, 지옥문 왕복 연출 구현. `HeldItem` 4종(삼지창/밀/우유/빈양동이) 및 효과음 5종(`whoosh`/`splash`/`chime`/`gulp`/`portal`) 추가, 메뉴바 "✨ 재미있는 모션 실행"에 8종 액션 + "☀️/🌙 낮밤 모드" 서브메뉴 추가. 검증: `swift build` 통과, `scripts/build_app.sh` 번들 생성 및 4초 실행 스모크 테스트.
- **[H1] 활 쏘는 스켈레톤(Skeleton Archer) 출현 및 방패 화살 튕겨내기 / 낮 햇빛 발화 고증 구축**: `SkeletonNode.swift`, `SkeletonBehaviorController.swift`, `SkeletonView.swift`, `SkeletonWindow.swift`, `ArrowEntityWindow.swift` 신규 구현. 해골 머리와 앙상한 갈비뼈/뼈다귀 팔다리, 3D 나무 활(`bowNode`) 조준/시위 당기기 모션. 포물선 궤적으로 날아가는 화살(`ArrowEntityWindow`) 발사 및 플레이어 방패 가드 시 `챙-!` 튕겨내기(`🛡️ 챙-! 화살 방어!`) 구현. 낮 시간대(06:00~18:00) 햇빛 노출 시 온몸 발화(`🔥 치이익! 햇빛이다!`) 및 창문 그늘 도주 AI 구현. 처치 시 뼈다귀(`🦴`), 화살(`➡️`), 활(`🏹`) 드롭. 메뉴바 "✨ 재미있는 모션 실행"에 "🏹 스켈레톤 소환" 및 "👾 가끔 스켈레톤 출현 모드" 토글 추가.
- **.idea/ 디렉토리 git ignore 및 저장소 인덱스 추적 제외**: JetBrains/IDEA 설정 파일(`.idea/`)을 `.gitignore`에 등록하고 원격 저장소 추적에서 안전하게 분리.
- **[M1-M4, L2-L4] 고급 원작 고증 7대 기능(창 압축, 모서리 낚시, 겉날개 활공, 늑대 꼬리, 스킨 필터, 인챈트 광택, 배터리 허기) 구축**:
  - `[M1]` `WindowMinimizer.swift` 및 `WindowSquashOverlayWindow.swift`: 접근성 API/AppleScript 기반 유압 피스톤 창 압축 최소화 구현.
  - `[M2]` `FishingLoot.swift`, 3D 낚싯대 모델 및 찌/입질 파티클, 6종 전리품(연어, 복어, 인챈트북, 네더라이트 등) 낚시 FSM 구현.
  - `[M3]` 3D 겉날개(`elytraNode`) 펼침/접힘 및 수평 활공 물리, 비행 중 클릭 시 폭죽 로켓 추진(`🚀`) 부스트 구현.
  - `[M4]` 늑대 꼬리 각도 체력 비례 고증(-35°~+45°) 및 3D 뼈다귀(`HeldItem.bone`) 급여 시 체력 100% 회복/하트 구현.
  - `[L2]` CoreImage 기반 6종 스킨 색조(Hue)/채도/흑백 필터 실시간 변환 구현.
  - `[L3]` `EnchantmentGlintShader.swift`: Metal 서피스 쉐이더 기반 마인크래프트 원작 보라색 일렁임 인챈트 광택 토글 구현.
  - `[L4]` `BatteryStatusMonitor.swift`: IOKit 기반 맥북 배터리 20% 이하 허기 꼬르륵 및 충전기 연결 시 활력 회복 연동.
- **[H1/H2/H3] 마인크래프트 원작 고증 3대 기능(고양이-크리퍼 상성, 왼손 방패 가드, 3D 엔더맨 눈싸움) 구축**:
  - `[H1]` 고양이 펫 소환 시 크리퍼가 반경 220pt 근처에 오면 도화선 점화를 취소하고 패닉 도주(`fleeingFromCat`)하는 원작 상성 구현.
  - `[H2]` 왼손 3D 방패 모델(`leftHandShieldAnchor`) 및 웅크리기(Shift) 시 방패를 앞으로 들어 올리는 가드 포즈 구현. 방패 가드 중 크리퍼 폭발 시 100% 피해 및 넉백 방어(`🛡️ 챙-! 완벽 방어!`).
  - `[H3]` 3D 복셀 엔더맨(`EndermanNode.swift`, `EndermanBehaviorController.swift`, `EndermanWindow.swift`, `EndermanView.swift`) 구현: 슬렌더 칠흑 바디, 발광 보라색 눈, 들고 있는 잔디 블록, 마우스 커서 눈 마주침 시 하악 턱 쩍 벌림(`jawNode`) 및 분노 진동, 시선 끊김 시 블록 던지고 175pt/s 돌진 + 보라색 파티클 순간이동, 처치 시 `🔮 엔더 진주` 드롭. 메뉴바 "✨ 재미있는 모션 실행"에 "👁️ 엔더맨 소환 (Cmd+E)" 및 "👾 가끔 엔더맨 출현 모드" 토글 추가.
- **마인크래프트 크리퍼(Creeper) 출현 및 무기/횃불 처치 전투 시스템 구축**: `CreeperNode.swift`, `CreeperBehaviorController.swift`, `CreeperView.swift`, `CreeperWindow.swift` 신규 구현. 3D 복셀 크리퍼(초록 위장 무늬, 찡그린 얼굴, 4개 다리 셔플 보행 사이클) 및 도화선 점화 시 부풀어 오름(Swell)과 흰색 고속 점멸 연출 구현. 2.8초 내 처치 실패 시 대폭발(플레이어 넉백 날리기 및 연기) 발동. 무기별 차별화된 피격 연출(다이아몬드 검 3데미지 원킬+화약 획득, 곡괭이 2데미지+넉백+경험치, 횃불 불붙어 패닉 도주, 맨손 1데미지 펀치). 플레이어 무기 휘두르기 공격 모션(`isAttackingWeapon`) 및 마우스 클릭 공격/드래그 지원. 크리퍼 출현 시 살기 감지 경계 대사("등골이 서늘한데...? 살기가 느껴져! 😨", "살기 감지! 무기 들 준비 해! ⚔️" 등) 및 펫 경계 반응(늑대 으르렁, 고양이 하악질) 연동. 크리퍼 처치 시 무기별 맞춤형 승리 대사 말풍선("칼날 끝에 자비란 없다! ⚔️", "곡괭이 맛이 어떠냐! ⛏️", "불장난은 위험하다고 했잖아? 🔥" 등) 출력 및 기쁨의 점프 모션 연동. 메뉴바 "✨ 재미있는 모션 실행"에 "💥 크리퍼 소환 (Cmd+K)" 및 설정에 "👾 가끔 크리퍼 출현 모드" On/Off 토글 추가.
- **3D 캐릭터 오른쪽 팔(화면 좌측) 누락 버그 수정**: `MinecraftCharacterNode.setupHierarchy`에서 2차 레이어(오버레이 소매) 구현 시 누락되었던 `bodyAnchor.addChildNode(rightArmJoint)` 코드를 복구하여 오른쪽 팔(메쉬, 오버레이 소매, 손 아이템)이 3D 씬에 정상적으로 렌더링되도록 수정.
- **마인크래프트 펫 동반자 시스템(Pet Companion System) 구축**: `PetKind.swift`, `PetNode.swift`, `PetBehaviorController.swift`, `PetView.swift`, `PetWindow.swift` 신규 구현. 4종 3D 복셀 펫(늑대, 고양이, 앵무새, 돼지) 모델링 및 애니메이션(걷기/뛰기 보행 사이클, 꼬리 살랑살랑 흔들기, 앵무새 날개 펄럭임, 얌전히 앉기, 침대 발치 수면) 구현. 플레이어와의 거리(750pt 초과 또는 모니터 이동)에 따른 자동 순간이동(파티클 연출), 플레이어 걸터앉기 및 수면 동기화, 펫 클릭 시 앉아/일어서 토글 및 먹이/하트 반응, 마우스 드래그 물리 지원. 메뉴바 "🐾 펫 동반자" 서브메뉴에서 펫 소환 및 소환 해제 연동.
- **방치된 macOS 알림창 감지 및 3D 삿대질/잔소리 구박 모션(Nag) 구현**: `NotificationCenterMonitor.swift` 신규 구현. Window Server의 `NotificationCenter` 알림 배너 창을 실시간 스캔하여 배너가 2개 이상 누적되었거나 5초 이상 방치된 경우 자동으로 구박 FSM(`.nag`) 트리거. 우측 상단 알림 배너를 향해 고개를 홱 돌려 째려보며, 오른팔로 삿대질하고 왼손은 허리에 올린 채 발을 쿵쿵 구르는 3D 구박 애니메이션(`isNagging`) 구현. 머리 위 팩폭 잔소리 말풍선("알림 좀 확인해! 💢", "완전 읽씹 장인이네! 😤" 등 5종) 출력. 메뉴바 "✨ 재미있는 모션 실행"에 "💢 알림 안 읽는다고 구박하기 (Cmd+N)" 즉시 실행 및 설정 메뉴에 "🔔 쌓인 알림 잔소리/구박 모드" On/Off 토글 추가.
- **TNT 폭파 연출 렉 최적화**: 파편 그리기에서 테두리 `stroke`를 제거하고(1980개 기준 12.2ms → 5.7ms, 스트로크가 그리기 비용의 절반), 색 변환을 프레임 루프 밖으로 옮겨 `CGContext.setAlpha`로 일괄 적용하며, 패널 밖 파편은 건너뛴다. 창 하나의 파편 상한을 3200 → 900(2x 기준)으로 낮추고 **동시 폭발하는 모든 창이 예산을 나눠 쓰도록** 했다(`BlockBreakOverlayWindow.debrisBudgetTotal=900`, `minimumDebrisPerWindow=60`, `AppController.didSelectTNTBreak`에서 `windows.count`로 분배). 이전에는 창마다 최대 3200개라 12창 동시 폭파 시 24,000개를 그렸다. 상한은 화면 배율에 따라 4배까지 늘어난다(1x는 같은 면적의 픽셀이 1/4). 도화선 점멸은 매 프레임 창 전체(1200x800)를 알파 블렌딩으로 다시 칠하던 것을 **불투명 흰 사각형 1회 그리기 + 창 `alphaValue` 점멸**로 교체했다(6.3ms/프레임 → 0.3ms 1회, 이후 재그리기 없음). 폭발 섬광 반지름은 760/664/460 → 290/300/190으로 줄이고 파편 위에 그리도록 순서를 바꿨으며(파편이 창을 덮는 동안 뒤에 그린 섬광은 보이지 않는다), 연기·불똥 개수도 파편 예산에 비례해 줄인다. 검증: 오프스크린 드라이버 min/avg 프레임 측정(단일 창 12.2~14.2ms → 4.2ms, 창 4개 2.4ms×4, 창 12개 1.7ms×12, 섬광 평균 13.6ms·최악 41ms → 2.9ms·최악 5.5ms, 도화선 0.3ms), 실제 `BlockBreakOverlayWindow` 창 수명주기 드라이버(도화선 alpha 0 ↔ 0.45~0.80 점멸 → 폭발 시 alpha 1.0 복귀 → 2.2초 뒤 `onBreakFinished` 호출), `screencapture -l` 프레임 캡처로 섬광·파편 비산 육안 확인, `scripts/build_app.sh`(swiftc Fallback) 빌드 및 3초 실행 스모크 테스트.
- **3D 마인크래프트 빨간 침대(Red Bed) 및 아이소메트릭 수면 모션 개선**: 기존의 단순 평면 눕기 모션이 화면상에서 잘 드러나지 않던 문제를 해결하기 위해, 원목 모서리 다리 4개, 베이스 프레임, 하얀색 베개, 빨간 양모 이불/매트리스로 구성된 3D 침대 모델(`bedNode`)을 추가. 수면 시 침대를 바닥에 배치하고 캐릭터와 침대를 입체 사각 시점(Pitch 0.25, Yaw 0.60)으로 회전하여 매트리스 위에 반듯하게 누워 베개에 머리를 얹고 호흡하는 실감 나는 수면 연출 구현.
- **[M1] 상단 메뉴바 발판(.menuBar) 인식, 걸터앉기 및 메뉴 인터랙션 구현**: `ScreenEnvironment.scanPlatforms`에서 상단 메뉴바(`visibleFrame.maxY`)를 독립 플랫폼 종류(`.menuBar`)로 자동 수집. 메뉴바 라인 위 보행 및 다리를 아래로 살랑살랑 흔드는 걸터앉기(`.sit`), 아래 화면을 내려다보는 모션(`.poke`) 지원. 캐릭터를 메뉴바 근처(상단 140pt 이내)에 놓으면 사다리를 설치하고 메뉴바로 상승 등반하거나 메뉴바 위에 즉시 착지. 메뉴바 "✨ 재미있는 모션 실행"에 "🪑 상단 메뉴바에 걸터앉기 (Cmd+M)" 즉시 호출 액션 추가.
- **[M2] 키보드 타이핑 속도(WPM) 감지 및 방방 뛰며 응원하는 모션(Cheer) 구현**: `TypingActivityMonitor.swift` 신규 구현(4초 롤링 타수 기반 실시간 WPM 계산, 시스템 전체 타 앱 타이핑 감지 및 시뮬레이션 지원). 빠른 타이핑(WPM 35 이상) 감지 시 자동으로 신나서 제자리에서 방방 뛰는 3D 모션(양팔을 번쩍 들고 흔들며 점프 홉) 및 이모지 파티클(`🔥`, `⚡`, `👏`, `🎉`, `💯`) 방출. 메뉴바 "✨ 재미있는 모션 실행"에 "🎉 코딩 신나게 응원하기 (Cmd+C)" 즉시 실행 추가 및 "⌨️ 타이핑 응원 모드 (WPM 감지)" On/Off 토글 지원.
- **[H1] 마인크래프트 스킨 2차 레이어(모자/자켓/소매/바지) 3D 오버레이 렌더링 구현**: Minecraft 1.8+ 64x64 표준 규격 6대 오버레이 부위(모자, 자켓, 좌/우 소매, 좌/우 바지) 정밀 UV 매핑. `MinecraftCharacterNode`에 각 관절 피벗을 부모로 하는 6개 오버레이 메쉬 노드(`headOverlayMesh`, `torsoOverlayMesh`, `rightArmOverlayMesh`, `leftArmOverlayMesh`, `rightLegOverlayMesh`, `leftLegOverlayMesh`)를 +0.08 크기로 추가하여 기준 메쉬를 입체적으로 감싸도록 구현. `SkinTexture.overlayMaterials`에서 알파 채널 검사(`hasVisiblePixels`)를 통해 투명 픽셀만 존재하는 미사용 부위는 노드를 자동 숨김(`isHidden = true`) 처리해 드로우콜을 절약. 내장 스킨(Alex의 3D 입체 머리카락/포니테일, Steve 헤어, Zombie 옷자락) 2차 레이어 픽셀 추가.
- **[H2] 다중 모니터 디스플레이 간 자유로운 이동 및 경계선 전환 물리 최적화**: `ScreenEnvironment.totalDesktopBounds` 및 `hasAdjacentScreen(from:onLeft:atY:)` 구현. 단일 모니터 기준의 강제 좌표 클램핑 및 바운스 반사를 개선하여, 인접 디스플레이가 존재하는 경계선에서는 캐릭터가 자유롭게 모니터를 넘어 비행, 낙하, 보행하도록 물리 엔진 수정. `CharacterBehaviorController`에서 모니터 경계선이 통로인 경우 엣지 반전/착석 FSM 트리거를 해제하고 인접 화면으로 계속 전진하도록 개선. `followCursor` 모드에서 다른 모니터에 있는 커서까지 경계선을 넘어 끝까지 추적하도록 확장. 모니터 간 높낮이 차이에 따른 동적 바닥 안전망 및 착지 시스템 최적화.
- **GitHub Actions CI/CD 바이너리 릴리스 파이프라인 구축**: `macos-14`(Apple Silicon) 러너 기반의 `.github/workflows/release.yml` 생성. `main` 브랜치 push 및 PR 시 빌드 검증 및 14일 보관 아티팩트(`OhMyFriend-macOS-arm64.zip`) 자동 업로드, `v*` 태그 push 시 GitHub Releases에 바이너리 자산 자동 업로드 및 릴리스 노트 자동 생성 파이프라인 연동. README에 바이너리 다운로드 및 Gatekeeper 해제 안내 갱신.
- **플레이어 닉네임 스킨 다운로더 개선 (Mojang 404 즉시 종료 & 서버 장애 시 Minotar 이중 검색 체계)**: 마인크래프트 정품 플레이어 닉네임 조회 시 공식 Mojang Profile API(`api.mojang.com`)를 단일 진실 공급원으로 판별하여, 404/204(존재하지 않는 닉네임) 응답 시 즉시 `notFound` 오류를 반환하고 검색을 종료(허위 Steve 노출 방지). 정상 플레이어(200 OK)의 경우 Mojang Session Server(`sessionserver.mojang.com`) -> 공식 `textures.minecraft.net` CDN 원본 PNG 직링크 -> Crafatar -> Minotar 순으로 안정적인 Fallback 체인을 적용. 만약 Mojang API 자체가 네트워크 단절/타임아웃/5xx 서버 오류로 다운된 경우에만 비상 대체 API로 Minotar를 조회하여 이중 검색을 수행. 3D 아바타 프리뷰는 겉옷/모자 오버레이를 완벽 지원하는 MC-Heads로 개선.
- **곡괭이 공격 크래시 수정**: 크랙 1단계 렌더 시 `drawBolt`에서 `pts[1...0]` 무효 슬라이스로 앱이 즉시 종료되던 SIGTRAP 크래시 수정(노출 길이가 첫 세그먼트보다 짧은 경우 가드). 1~10단계 전 구간 드라이버 렌더로 검증.
- **화면 기록 권한 프롬프트 제거**: 파편 텍스처용 대상 창 실사 스냅샷(`CGWindowListCreateImage`) 캡처를 삭제하고 시스템 라이트/다크 톤 팔레트 전용으로 단순화. `ScreenEnvironment.windowSnapshotCGImage` API 제거.
- **백색 플래시 이펙트 제거**: 파편 폭발 직전 하얀 창 화면이 노출되는 것처럼 보이던 연출 제거. '앱 창 부수기' 메뉴 단축키(Cmd+B)도 제거(오입력으로 사용 중 앱이 종료되는 것 방지, 메뉴 선택 시에만 발동).
- **파편 격자 창 크기 정합**: `Int(width/cell)` 내림으로 오른쪽·위 가장자리에 남던 빈 틈을 제거하고 창 폭/높이를 셀 수로 나눠 정확히 타일링. 대기 중인 파편도 제자리에 렌더링하도록 수정해, 부서지기 전 0.06초 동안 창이 블록 격자로 바뀐 모습이 창 영역과 일치(가장자리 커버리지 0.93~0.94, 창 밖 유출 0.00 측정).
- **파편 비산 범위·힘 강화**: 오버레이 패널 여백이 곧 드로잉 클리핑 경계임을 반영해 좌우 340 / 상단 420 / 하단 640pt까지 확장하고 초기 속도·회전을 상향(측정: t=0.6초 시점 창 밖 좌 284 / 우 308 / 상 271pt 비산, 좌우 총 폭 1452pt ≈ 창 폭의 1.7배).
- **곡괭이 채굴 → TNT 폭파 연출 전환**: 마인크래프트 TNT 실제 동작(도화선 80틱=4초, 점화 중 하얗게 점멸)을 조사해 반영. 캐릭터가 TNT를 치켜들고(0.45초) 앉아서 창 표면에 내려놓은 뒤(0.95초) 점화음과 함께 도화선 4초 동안 창이 사각 펄스로 점멸하고, 도화선 종료 순간 대상 앱 종료 + 폭발음 + 흰 코어·주황 링 섬광·연기·불똥·창 블록 파편 비산이 동시에 일어난다. 캐릭터는 폭풍에 튕겨 날아가 착지(`PhysicsEngine.launch`). 기존 크랙 단계 이펙트·곡괭이 모델은 제거하고 화면 공간 TNT 엔티티(`TNTEntityWindow.swift`, 픽셀아트)와 사운드 `.ignite`/`.explode` 추가.
- **폭파 대상 전 창 확장**: 창 단위 종료(AX 접근성 권한 필요) 대신 앱 종료 방식을 유지하되, 대상 앱의 모든 창(최대 12개)에 도화선 점멸과 폭발 연출을 동시 적용. `ScreenEnvironment.windowsForApp(pid:)` 신설(창 2개 수집·좌표 정합 검증).

- **사다리 타고 창문 내려가기 (Ladder Descent)**: 창문 발판 위에서 사다리를 걸고 **창문 높이만큼만** 타고 내려가는 기능 추가. `Platform.yBottom`(창문 아래 끝 좌표)과 `CharacterBehaviorController.canDescend(from:)`(창문이며 높이 180pt 이상)으로 자격을 판정하고, `PhysicsState.climbing` + `beginClimb()/releaseClimb()`로 등반 중 중력·착지 판정을 멈추고 y를 행동 컨트롤러가 구동한다. FSM `climbDown`(0.55초 사다리 설치 → 220pt/s 하강)은 매 프레임 창문을 재조회해 창이 움직이면 사다리가 따라가고, 창이 닫히거나 사다리 끝(창 아래 끝)에 닿으면 사다리를 지우고 낙하시킨다(남은 높이는 기존 물리로 아래 창문/바닥/Dock에 착지). `MinecraftCharacterNode.isClimbing`은 몸을 π만큼 돌려 창문을 마주본 채(등을 보이며) 양팔 교차 리치·다리 교차 디딤 모션을 재생하고 고개 시선 추적을 멈춘다. `LadderOverlayWindow`(레벨 `floating - 1`, 폭 44pt, 레일 2개 + 16pt 간격 가로대 전체를 설치 시점에 한 번에 생성, 완료 시 0.35초 페이드아웃) 신규. 진입점: 메뉴 '🪜 사다리 타고 창문 내려가기'(Cmd+L) + 자율 모드 확률 밴드 9%(12초 쿨다운). 검증: 헤드리스 드라이버(자격 판정 / 사다리 사각형 200~604 정확·등반 중 변동 없음 / 220pt/s·총 143프레임 / 창 하단 이탈 후 바닥 낙하 / 창 소멸 폴백 / 드래그·클릭 중단 / 트리거 6종 차단 / 쿨다운), 창 서버 통합 하네스 15개 체크(오버레이 실제 표시, 폭 44pt, 레이어 2 < 캐릭터 3, 사다리 상단 = 창 상단+4pt·하단 = 창 하단·길이 = 창 높이+4pt 정확, 등반 중 위치 변동 0.0pt, 창 하단까지 하강 후 바닥 착지, 이탈 2.17초·오버레이 소멸 2.78초, 등반 중 yaw = π), `LadderEffectView` 오프스크린 렌더 픽셀 검증(가로대 39개가 상·중·하 전 구간 균일, 레일 640/640행).
- **등반 중 인터랙션 안전장치**: 등반 중에는 공중제비/쉬프트 댄스/손 흔들기/낮잠/먹기/블록 캐기/곡괭이 공격 트리거를 무시하고, 캐릭터를 드래그하거나 클릭하면 사다리에서 손을 놓고 낙하한다(`cancelClimbIfActive`, `releaseClimb`). 등반 중 커서 근접 인사(Wave)도 스킵한다.
- **사다리에서 내려온 뒤 정면 보기 수정**: 등반이 끝난 뒤에도 몸이 뒤로 돌아 있던 문제를 수정. 뒤돌기는 등반 중에만 적용하고, `MinecraftCharacterNode.isClimbing`에 `didSet`을 두어 true→false로 바뀌는 순간(사다리 끝 도달·클릭·드래그·창 닫힘) 몸 회전을 0으로 되돌린다. 검증: 드라이버·창 서버 하네스에서 등반 중 yaw = π, 내려온 직후 yaw = 0 확인.
- **드래그 드롭 → 사다리 자동 등반**: 캐릭터를 창문 안(창 아래 끝~위 끝)에 놓으면 그 창문 위쪽 끝에 얹고 착지 모션 뒤 사다리 등반을 자동 시작하도록 `CharacterBehaviorController.placeDropOnWindow(physics:platforms:)`와 `dropSnapSpeedLimit`(260pt/s) 추가, `AppController.characterViewDidEndDrag`에서 연결. 세게 던지면 기존 던지기 유지, 창문이 없는 지점에서는 무동작, 겹친 창문은 위쪽 끝이 가장 가까운 것을 고른다. 검증: 헤드리스 드라이버 12개 체크(얹기·겹침 선택·창문 밖 무동작·자동 등반 시작 144프레임·사다리 = 창 높이 378/200/44/404·창 하단 이탈 후 바닥 착지·반복 없음), 창 서버 하네스에서 드롭만으로 등반 시작→착지 전 구간 + 오버레이 소멸까지 확인.
- **드래그 드롭 동작 교체 (순간이동 하강 → 사다리 상승)**: 위 동작을 "창문 위로 올린 뒤 내려오기"에서 **"놓인 자리에서 그 창문 위쪽 끝까지만 사다리를 세우고 올라가기"**로 교체. `CharacterBehaviorController.climbUpFromDrop(physics:characterNode:platforms:)`가 놓인 지점을 담은 창문 중 z-순서상 가장 앞 창문을 골라 그 자리에서 상승 등반을 시작하고, FSM 등반 상태를 `climb(phaseTimer:isPlacing:isUp:)`로 일반화해 하강(창 아래 끝까지 내려간 뒤 낙하)과 상승(창문 위쪽 끝에 올라섬)을 함께 처리한다. `PhysicsEngine.endClimb(on:)` 복귀, `MinecraftCharacterNode.climbUp`으로 팔다리 위상 반전, 상태 문구도 오르내리기를 구분. 검증: 헤드리스 드라이버(놓인 자리 350pt 유지·순간이동 없음·상승 103프레임·y 단조 증가·창문 위 600pt 정확 착지·사다리 338~604·창문 밖/이미 위쪽 끝이면 미발동), 창 서버 하네스 17개 체크(사다리 266pt = 놓인 자리→창문 위, 등반 중 위치 변동 0.0pt, 251pt 상승 후 창문 위 착지, 완료 1.72초·오버레이 소멸 2.35초, 등반 중 yaw = π → 올라온 뒤 0).

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
