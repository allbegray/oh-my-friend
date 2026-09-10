이 문서는 Oh My Friend 프로젝트의 우선순위별 향후 개선 및 기능 개발 백로그를 관리합니다.

# 백로그

## 높음 (H)
(현재 등록된 높음 순위 백로그가 없습니다.)

## 중간 (M)
- [ ] [M1] 창 치우기(최소화) 인터랙션 — "🗜️ 창 압축해서 Dock으로 밀어넣기"
  - 선행: 손쉬운 사용(Accessibility) 권한. `AXUIElementCreateApplication` → `kAXWindowsAttribute` → `kAXPositionAttribute`/`kAXSizeAttribute`로 CGWindowID 창 매칭(4pt 허용 오차) → `kAXMinimizedAttribute = true` (실패 시 `kAXMinimizeButtonAttribute` 프레스 폴백). 화면 기록 권한은 사용하지 않음.
  - `WindowMinimizer.swift` 신규: 권한 확인(`AXIsProcessTrustedWithOptions`) + `minimize(windowID:pid:) -> Result`
  - FSM: `CharacterBehaviorController.State.squash(timeLeft:)`, `startSquashMinimize(on:duration:completion:)`, `squashProgress` (`startPickaxeAttack` 패턴 복제)
  - 연출: `WindowSquashOverlayWindow.swift` 신규(BlockBreakOverlayWindow 형제) — 상단에서 하강하는 압축 판, 압축률 눈금, 픽셀 먼지 → 마지막 프레임에 실제 최소화(지니 효과)가 이어받음. 캐릭터는 양팔 내려누르기 `isPressing` 포즈, 발판이 사라지면 기존 물리로 낙하 → `landedCrouch`
  - 진입점: 메뉴 "🗜️ 이 창 치우기"(Cmd+M). 자율 발동은 기본 OFF(사용 중인 창 방해 방지), 메뉴 토글로만 허용
- [ ] [M2] 🎣 창문/Dock 모서리 낚시 (Fishing) 인터랙션
  - 창문 모서리나 Dock에 걸터앉아 낚싯대를 던지고 물결 파티클을 보다가, 찌가 퐁당 가라앉는 순간 낚아채어 물고기/보물 획득
- [ ] [M3] 🪽 겉날개 (Elytra) 활공 및 폭죽 추진 비행
  - 높은 창문이나 상단 메뉴바에서 떨어질 때 등 뒤의 겉날개를 펴고 화면을 부드럽게 글라이딩 활공하며 비행 중 클릭 시 폭죽 추진 가속
- [ ] [M4] 🐺 늑대 꼬리 각도로 보는 체력/호감도 및 먹이(뼈다귀) 주기
  - 뼈다귀를 주면 하트와 함께 꼬리가 45° 올라가고, 시간이 지나면 꼬리 각도가 내려가는 원작 체력 디테일 고증

## 낮음 (L)
- [ ] [L1] 화면 위에 여러 마리의 캐릭터를 동시에 소환하여 함께 놀게 하는 멀티 캐릭터 모드 지원
- [ ] [L2] 스킨 색조(Hue/Saturation) 조절 및 간단한 인앱 픽셀 수정 기능 추가
- [ ] [L3] 🔮 무기/장비 보라색 인챈트 마법 광택(Enchantment Glint) 쉐이더 연출
- [ ] [L4] 🍗 맥북 배터리 잔량 연동 허기(배고픔) 시스템
  - 배터리 20% 이하 시 꼬르륵 소리와 지친 모션, 황금사과를 먹여 충전 격려
