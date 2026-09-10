이 문서는 Oh My Friend 프로젝트의 우선순위별 향후 개선 및 기능 개발 백로그를 관리합니다.

# 백로그

## 높음 (H)
- [ ] [H1] 마인크래프트 스킨 2차 레이어(모자/자켓/소매/바지 외투) 3D 오버레이 렌더링 지원
- [ ] [H2] 다중 모니터 환경에서 디스플레이 간 자유로운 이동 및 경계선 전환 물리 최적화

## 중간 (M)
- [ ] [M1] macOS 상단 메뉴바 라인을 발판으로 인식하여 메뉴바 위에 걸터앉는 인터랙션 추가
- [ ] [M2] 키보드 타이핑 속도(WPM) 감지 시 옆에서 신나서 방방 뛰며 응원하는 모션 추가
- [ ] [M3] 사다리 타고 창문 내려가기 (Ladder Descent) — 창문 발판 위에서 사다리를 걸고 아래 플랫폼까지 등반
  - `PhysicsState.climbing` + `beginClimb()/endClimb(on:)` 신설 (등반 중 중력·착지 판정 정지, y는 행동 컨트롤러가 구동)
  - `Platform` 기준 `landingBelow(from:atX:in:)` 목적지 탐색 헬퍼 (매 프레임 재계산 → 창이 움직여도 안전)
  - `LadderOverlayWindow`(레벨 `floating - 1`) 신규: 두 레일 + 16pt 간격 발판, 진행률만큼 발판 점진 노출, 완료 시 페이드아웃
  - `MinecraftCharacterNode.isClimbing` 등반 포즈(양팔 교차 오버헤드 리치 + 다리 교차), `CharacterBehaviorController.climbDown` 상태
  - 진입점: 메뉴 "🪜 사다리 타고 창문 내려가기"(Cmd+L) + 자율 모드 확률 밴드, 쿨다운 12초

## 낮음 (L)
- [ ] [L1] 화면 위에 여러 마리의 캐릭터를 동시에 소환하여 함께 놀게 하는 멀티 캐릭터 모드 지원
- [ ] [L2] 스킨 색조(Hue/Saturation) 조절 및 간단한 인앱 픽셀 수정 기능 추가
